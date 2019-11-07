# Use an official Golang runtime as the parent image
FROM golang:1.12

# Set the working directory in the container to /app
WORKDIR /app

# Copy the current directory contents into the container at /app
ADD . /app

RUN go build -o main .

# Make the container's port 80 available to the outside world
EXPOSE 80

# Run the Go app using node when the container launches
CMD ["./main"]
