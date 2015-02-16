EventEmitter = (require "events").EventEmitter
Q = require "q"

class AudioStream extends EventEmitter
  constructor: ->
    @stream = null
    @ctx = new webkitAudioContext()
  
  getSourceStream: ->
    deferred = Q.defer()
    MediaStreamTrack.getSources (infos) =>
      navigator.webkitGetUserMedia {
        audio: true
      }, (res) =>
        deferred.resolve @stream = @ctx.createMediaStreamSource res
      , (e) ->
        deferred.reject e
    return deferred.promise

module.exports = AudioStream
