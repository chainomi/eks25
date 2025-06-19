FROM python:3.8-alpine

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh

# Make dir app
RUN mkdir /app_flask

WORKDIR /app_flask

# Copy the source from the current directory to the Working Directory inside the container
COPY . .

#install dependencies
RUN pip install -r requirements.txt


# add flask-user to run app
RUN adduser --disabled-password flask-user

# change working directory --disabled-passwordownership to flask-user
RUN chown flask-user /app_flask

USER flask-user 

# Run the executable
CMD ["python", "app_flask_api.py"]