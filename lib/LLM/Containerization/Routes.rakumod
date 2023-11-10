use Cro::HTTP::Router;
use Cro::HTTP::Router::WebSocket;
use Cro::HTTP::Server;

use JSON::Fast;
use URI::Encode;

use LLM::Functions;
use ML::FindTextualAnswer;

sub routes() is export {
    route {

        my $user-id = '';
        my $conf-spec = 'ChatGPT';
        my $prompt = '';

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
            content 'application/json', to-json({ :$prompt, :$user-id, :$conf-spec });
        }

        # Setup
        get -> 'setup', Str :$api_key= '', Str :$user_id= '', Str :$llm = 'ChatGPT' {

            my $response = '';

            # API key setup
            if $api_key {
                given $llm {
                    when $_.lc ∈ <openai chatgpt> {
                        %*ENV<OPENAI_API_KEY> = $api_key
                    }
                    when $_.lc ∈ <palm bard> {
                        %*ENV<PALM_API_KEY> = $api_key
                    }
                    default {
                        $response = 'Unknown spec for the paramter llm.'
                    }
                }
            }

            if $user_id { $user-id = $user_id }

            # Response
            if !$response {
                $response = 'Setup is successfull.';
            }

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

        # Name of the service
        get -> {
            content 'text/html', "<h1> LLM::Containerization </h1>";
        }
    }
}