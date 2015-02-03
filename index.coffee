express = require "express"
irc = require "twitch-irc"
pg = require 'pg'
app = express()
client = new irc.client
    options:
        debug: true
        tc: 3
    channels: [process.env.TWITCH_CHANNEL]

client.connect()
client.addListener "chat", (channel, user, message) ->
    pg.connect process.env.DATABASE_URL, (err, client) ->
        return console.error(err) if err?
        client.query 'SELECT * FROM users WHERE name=$1', [user.username], (err, res) ->
            return console.error(err) if err?
            if res.rowCount is 0
                if (match = message.match(/^!prop ([\w ]+)$/)) isnt null
                    client.query 'INSERT INTO props(name) VALUES ($1) RETURNING id', [match[1]], (err, insert) ->
                        return console.error(err) if err?
                        client.query 'INSERT INTO users(name, vote) VALUES ($1, $2)', [user.username, insert.rows[0].id], (err) ->
                            console.error(err) if err?
                            console.log "User #{user.username} proposed #{match[1]}"
                else if (match = message.match(/^!vote (\d+)$/)) isnt null
                    client.query 'INSERT INTO users(name, vote) VALUES ($1, $2)', [user.username, match[1]], (err) ->
                        console.error(err) if err?
                        console.log "User #{user.username} voted for #{match[1]}"

app.set 'view engine', 'jade'
app.set 'views', __dirname

app.get '/', (req, res) ->
    pg.connect process.env.DATABASE_URL, (err, client) ->
        if err?
            console.error(err)
            return res.status(500).send("There was an error connecting to the database.")
        client.query 'SELECT props.*, (SELECT COUNT(*) FROM users WHERE users.vote = props.id) AS note FROM props ORDER BY note', (err, result) ->
            if err?
                console.error(err)
                return res.status(500).send("An error was encountered while fecthing the poll data")
            res.render "index", {props: result.rows}

app.listen process.env.PORT, -> console.log "Listening on port #{process.env.PORT}"
