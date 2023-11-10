# How to use

## Introduction

In this document we show how to utilize Large Language Model (LLM) functionalities
through a specialized Web interface.

We also show how to build a Docker image and run a container with it.

------

## Docker 

Build the Docker image with the command:

```
docker build --no-cache --build-arg PAT_GIT=MYXXX -t llm:1.0 -f docker/Dockerfile .
```

Run a container over the image with the command:

```
docker run --rm -p 9191:9191 --name webllm2 -t llm:1.0  
```

To stop the container run the command:

```
docker container stop webllm2
```

------

## Setup

### OpenAI API key

Set OPENAI_API_KEY with the URL:

```
http://localhost:9191/setup?api_key=<YOUR_API_KEY>
```

Or the command:

```
http://localhost:9191/setup?llm=ChatGPT&api_key=<YOUR_API_KEY>
```

### PaLM API key

Set PALM_API_KEY with the URL:

```
http://localhost:9191/setup?llm=PaLM&api_key=<YOUR_API_KEY>
```

------

## Question answering

An LLM-based Question Answering System (QAS) invocation can be utilized with the URL: 

```
http://localhost:9191/qas?text='Today is Wednesday and it is 35C hot!'&questions='What day? How hot?'
```

You can specify the LLM service you want to use with the parameter `llm`:

```
http://localhost:9191/qas?llm=PaLM&text='Today is Wednesday and it is 35C hot!'&questions='What day? How hot?'
```

------

## References

[AAp1] Anton Antonov,
["LLM::Functions"](https://github.com/antononcube/Raku-LLM-Functions),
(2023),
[GitHub/antononcube](https://github.com/antononcube).

[AAp2] Anton Antonov,
["LLM::FindTextualAnswer"](https://github.com/antononcube/Raku-ML-FindTextualAnswer),
(2023),
[GitHub/antononcube](https://github.com/antononcube).
