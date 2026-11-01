extends RefCounted
## Where Garden Times connects. These values ship inside the game and are not
## secrets: what protects the data is firebase/database.rules.json.

const DB_HOST := "virus-roller-default-rtdb.firebaseio.com"
## Firebase console: Project settings > General > Web API key.
const API_KEY := "AIzaSyBiXXqx7rMYLs9y4tzCC4vd5e91mAbwnPY"
## Google Cloud console: an OAuth client of type "TVs and Limited Input devices",
## made in the same project. Its secret goes in net_secrets.gd, which stays out of
## the repository: GOOGLE_CLIENT_SECRET as a const. Without that file there is no Google button.
const GOOGLE_CLIENT_ID := "1050036909657-983101dfqpfasl9htj50ilneo2e290rm.apps.googleusercontent.com"
## All game data lives under this key, so the database can hold other things too.
const ROOT := "gag"
