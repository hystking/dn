param = (require "site-param")()
Q = require "q"
AudioStream = require "./module/audio-stream"
mergeBuffers = require "merge-audio-buffers"

audioStream = new AudioStream
player = null
onStateChnageCallback = ->

youtubeOnStateChange = (e) ->
  onStateChnageCallback e

window.onYouTubeIframeAPIReady = ->
  player = new YT.Player "dragonNight",
    height: 390
    width: 640
    videoId: "SEOBibulqWI"
    events:
      onReady: ->
      onStateChange: youtubeOnStateChange

playAndRecord = (stream) ->
  deferred = Q.defer()
  recorder = new Recorder stream,
    workerPath: "js/lib/recorder/recorderWorker.js"
  onStateChnageCallback = (e) ->
    recorder.record() if e.data is 1
    deferred.resolve recorder if e.data is 2
  player.playVideo()
  return deferred.promise

getBuffers = (recorder) ->
  deferred = Q.defer()
  recorder.stop()
  recorder.getBuffer (buffers) ->
    deferred.resolve buffers
  return deferred.promise

playBufferWithVideo = (buffers) ->
  deferred = Q.defer()
  ctx = audioStream.ctx
  newSource = ctx.createBufferSource()
  newBuffer = ctx.createBuffer 2, buffers[0].length, ctx.sampleRate
  (newBuffer.getChannelData 0).set buffers[0]
  (newBuffer.getChannelData 1).set buffers[1]
  newSource.buffer = newBuffer
  newSource.connect ctx.destination
  onStateChnageCallback = (e) ->
    if e.data is 1
      newSource.start 0
      deferred.resolve()
  player.seekTo 0
  player.playVideo()
  return deferred.promise

globalBuffers = null

mergeToGlobalBuffers = (buffers) ->
  if globalBuffers
    console.log globalBuffers
    globalBuffers = mergeBuffers [
      globalBuffers
      buffers
    ], audioStream.ctx
    ###
    globalBuffers[1] = mergeBuffers [
      globalBuffers[1],
      buffers[1]
    ], audioStream.ctx
    ###
  else
    globalBuffers = buffers
  return Q.when globalBuffers

###
audioStream.getSourceStream()
.then playAndRecord
.then getBuffers
.then mergeToGlobalBuffers
.then playBufferWithVideo
.then () ->
  'do`nathing'
###
buttonRecord.addEventListener 'click', ->
  audioStream.getSourceStream()
  .then playAndRecord
  .then getBuffers
  .then mergeToGlobalBuffers
  .then playBufferWithVideo
  .catch (e) ->
    console.log e

