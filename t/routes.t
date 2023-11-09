use Cro::HTTP::Test;
use Test;
use LLM::Containerization::Routes;

test-service routes, {
    test get('/'),
            status => 200,
            body-text => '<h1> LLM::Containerization </h1>';
}

done-testing;
