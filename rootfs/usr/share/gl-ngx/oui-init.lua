local db = require "oui.db"

math.randomseed(ngx.time())

db.init()