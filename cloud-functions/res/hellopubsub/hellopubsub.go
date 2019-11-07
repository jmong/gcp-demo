package hellopubsub
/*
 * @see https://cloud.google.com/functions/docs/writing/background
 */

import (
    "context"
    "log"
)

// PubSubMessage is the payload of a Pub/Sub event.
type PubSubMessage struct {
    Name []byte `json:"name"`
}

// HelloPubSub consumes a Pub/Sub message.
func HelloPubSub(ctx context.Context, m PubSubMessage) error {
    name := string(m.Name)
    if name == "" {
        name = "World"
    }
    log.Printf("Hello, %s!", name)
    return nil
}
