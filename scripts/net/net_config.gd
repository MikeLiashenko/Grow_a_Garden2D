extends RefCounted
## Where Garden Times connects. These values ship inside the game and are not
## secrets: what protects the data is firebase/database.rules.json.

const DB_HOST := "virus-roller-default-rtdb.firebaseio.com"
## Firebase console: Project settings > General > Web API key.
const API_KEY := "AIzaSyBiXXqx7rMYLs9y4tzCC4vd5e91mAbwnPY"
## Google Cloud console: an OAuth client of type "TVs and Limited Input devices",
## made in the same project. Empty hides the Google button.
const GOOGLE_CLIENT_ID := ""
const GOOGLE_CLIENT_SECRET := ""
## All game data lives under this key, so the database can hold other things too.
const ROOT := "gag"
