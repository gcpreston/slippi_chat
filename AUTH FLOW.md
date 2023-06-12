AUTH FLOW

- Electron app starts and asks for player code
- Code is entered and app gets token for that player code from backend
- Token is sent with each request. Actions such as game_start authorize against the signed player code

PROBLEMS
- Manually requesting a token from the backend

CONSIDERATIONS
- Can infer player code from slippi replay directory (if there is a way to find the path automatically)
- Each client installation could include a unique secret key signed by the backend
  - What prevents someone from making requests to generate these keys? Homogenous solution as API key

- Have secret key bundled with precompiled executable
  - Would prevent custom builds from talking to the backend, which is good.
  - Does not individually identify clients but it does ensure that requests are being made from a client
  - What about packet sniffers???? Do we not care because of HTTPS?

- Ok so we know a request came from a client. What if someone is pretending to be someone else?
  - Should tokenize the game start event with the secret key and send that to the server for game_start
  - Both legit players could have this and an imposter couldn't (is this true? What metadata is contained? And is it the same for both players?)
  - Allow the imposter to connect to the channel, because we don't know who is who
  - If there are multiple connections and one establishes a game successfully, cut off the other ones
  - if we do this, do we even need to have a secret key for the client? Maybe not
  - Say someone manually re-sends a valid game start event. We can just ignore it.
  - I think there should still be secret key validation to minimize curious people lol

BIG IDEAS
* An imposter should not be able to force a legit connection to disconnect or be invalidated
* An imposter should not be able to generate a real game_start event
  - Can force requests from both clients to come in within a second or so of each other
* Having a way to manually disconnect (bonus points: ban) bad actors would be great

WISHLIST
* 
