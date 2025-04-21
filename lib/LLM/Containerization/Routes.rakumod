use Cro::HTTP::Router;
use Cro::HTTP::Router::WebSocket;
use Cro::HTTP::Server;

use JSON::Fast;
use URI::Encode;

use LLM::Functions;
use LLM::RetrievalAugmentedGeneration;
use ML::FindTextualAnswer;
use XDG::BaseDirectory :terms;

sub routes() is export {
    route {

        my $user-id = '';
        my $conf-spec = 'ChatGPT';
        my $max-tokens = 4096;
        my $temperature = 0.5;
        my $prompt = '';
        my $dir-vdb = LLM::RetrievalAugmentedGeneration::default-location();
        my $vdb = Nil;
        my $vdb-conf = Whatever;

        # Is ready
        get -> 'is_ready' {
            content 'application/json', to-json({ :is-ready });
        }

        # Is this needed?
        #        my $chat = Supplier.new;
        #        get -> 'chat' {
        #            web-socket -> $incoming {
        #                supply {
        #                    whenever $incoming -> $message {
        #                        $chat.emit(await $message.body-text);
        #                    }
        #                    whenever $chat -> $text {
        #                        emit $text;
        #                    }
        #                }
        #            }
        #        }

        # Show setup
        get -> 'show_setup' {
            content 'application/json', to-json({ :$prompt, :$user-id, :$conf-spec, :$max-tokens, :$temperature, vdb-id => $vdb.id });
        }

        # Setup
        get -> 'setup',
               Str :$api_key= '',
               Str :$user_id= '',
               Str :llm_service(:$llm) = 'ChatGPT',
               UInt :maxtokens(:$max_tokens) = 4096,
               Str :temperature(:$temp) = '0.5' {

            my $response = '';

            # API key setup
            if $api_key {
                given $llm {
                    when $_.lc ∈ <openai chatgpt> {
                        %*ENV<OPENAI_API_KEY> = $api_key
                    }
                    when $_.lc ∈ <palm bard gemini> {
                        %*ENV<PALM_API_KEY> = $api_key
                    }
                    when $_.lc ∈ <mistral mistralai> {
                        %*ENV<MISTRAL_API_KEY> = $api_key
                    }
                    default {
                        $response = 'Unknown spec for the parameter llm.'
                    }
                }
            }

            if $user_id { $user-id = $user_id }

            # Response
            if !$response {
                $response = 'Setup is successful.';
            }

            $conf-spec = $llm;
            $max-tokens = $max_tokens;
            $temperature = $temp.Numeric;

            content 'application/json', to-json({ 'import' => $response });
        }


        # Invoking QAS
        get -> 'qas',
               Str :$text!,
               Str :$questions!,
               Str :$llm = 'chatgpt' {

            ## Remove wrapper quotes
            my $cleanText = uri_decode($text);
            if $cleanText ~~ / ^ ['"' | '\''] .* ['"' | '\''] $ / {
                $cleanText = $cleanText.substr(1, *- 1)
            }

            my $cleanQuestions = uri_decode($questions);
            if $cleanQuestions ~~ / ^ ['"' | '\''] .* ['"' | '\''] $ / {
                $cleanQuestions = $cleanQuestions.substr(1, *- 1)
            }

            # Questions
            my @questions = $cleanQuestions.split('?', :skip-empty);
            @questions .= map({ $_.trim ~ '?' });
            note @questions;

            # Configuration / evaluator
            #my $llmConf = llm-configuration($conf, prompts => default-prompt);

            # Find answers
            my $response = find-textual-answer($cleanText, @questions, finder => $llm, :pairs);

            # Result
            note "Response: ", $response;
            content 'application/json', to-json($response);
        }

        # Show vector databases
        get -> 'vdb_summary' {
            my @field-names = <id name item-count dimension version llm-service llm-embedding-model created>;
            vector-database-objects(f=>'hash', :flat)
                    ==> { $_.map({ $_<created> = $_<file>.IO.created.DateTime.Str.subst('T',' ').substr(^19); $_}).sort(*<created>).reverse }()
                    ==> { $_.map({ @field-names Z=> $_{@field-names} })».Hash }()
                    ==> my @summary;

            content 'application/json', to-json(@summary);
        }

        # Show vector databases
        get -> 'vdb_load', Str :$id! {
            # It is good to be able to load multiple vector databases
            my @vdbSummary = vector-database-objects($dir-vdb, f=>'hash', :flat);
            my @vdbs = @vdbSummary.grep({ $_<id> ∈ [$id, ] }).map({ create-vector-database(file => $_<file>) });

            if @vdbs.elems == 0 {
                return content('application/json', to-json({ :!found }));
            }

            # Merge databases
            #my $vdbObj2 = vector-database-join(@vdbs)
            $vdb = @vdbs.head;

            # Make the VDB configuration
            $vdb-conf = llm-configuration(@vdbSummary.head<llm-service>, embedding-model => @vdbSummary.head<llm-embedding-model>);

            content 'application/json', to-json({ :found });
        }

        # Show vector databases
        get -> 'vdb_nearest', Str :$query!, UInt :n(:$nns) = 5, Str :d(:$dataset) = 'true' {
            # Using the LLM embedding configuration made during the VDB load

            # Get the query vector
            my $vec = llm-embedding($query, e => $vdb-conf).head».Num.Array;

            # Often enough I get messages that vectors are not of the same length.
            # When I put in this print-outs that message disappears.
            #note "vec.elems = {$vec.elems}";
            #note (:$vec);

            if $dataset.lc ∈ <true yes> {
                # Find nearest neighbors
                my @nns = |$vdb.nearest($vec, $nns, prop => <label distance>);

                # Make the result
                my @dataset = @nns.map({ %( id => $_.head, distance => $_.tail, item => $vdb.items{$_.head} ) }).Array;

                content 'application/json', to-json(@dataset);
            } else {
                # Find nearest neighbors
                my @nns = |$vdb.nearest($vec, $nns).flat(:hammer);

                # Make the result
                my @paragraphs = @nns Z=> $vdb.items{|@nns};

                content 'application/json', to-json(@paragraphs);
            }
        }

        # Show vector databases
        get -> 'rag', Str :q(:$query)!, Int :n(:$nns) = 5, Str :r(:$request) = "Answer:\n\n\t\$QUERY\n\nby using the following text:\n"  {
            # Using the LLM embedding configuration made during the VDB load
            # Get the query vector
            my $vec = llm-embedding($query, e => $vdb-conf).head».Num.Array;

            # Find nearest neighbors
            my @nns = |$vdb.nearest($vec, $nns).flat(:hammer);

            # Retrieve text chunks
            my @paragraphs = $vdb.items{|@nns};

            # Using LLM configuration from setup
            my $conf = llm-configuration($conf-spec, :$max-tokens, :$temperature);

            # Make the result
            my $res = llm-synthesize([
                $request.subst('$QUERY', $query, :g),
                @paragraphs.join(" "),
            ], e => $conf);

            content 'application/json', to-json($res);
        }

        # Name of the service
        get -> {
            content 'text/html', "<h1> LLM::Containerization </h1>";
        }
    }
}