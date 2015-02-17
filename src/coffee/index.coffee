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
    height: 10
    width: 10
    videoId: "SEOBibulqWI"
    events:
      onReady: ->
      onStateChange: youtubeOnStateChange

initRecorder = (stream) ->
  recorder = new Recorder stream,
    workerPath: "js/lib/recorder/recorderWorker.js"
  Q.when recorder

playAndRecord = (recorder) ->
  deferred = Q.defer()
  recorder.clear()
  onStateChnageCallback = (e) ->
    recorder.record() if e.data is 1
    deferred.resolve recorder if e.data is 2
  player.stopVideo()
  player.seekTo 0
  player.playVideo()
  return deferred.promise

stopRecord = (recorder) ->
  player.stopVideo()
  recorder.stop()

getBuffers = (recorder) ->
  deferred = Q.defer()
  recorder.getBuffer (buffers) ->
    deferred.resolve buffers
  return deferred.promise

playBufferWithVideo = (buffers) ->
  deferred = Q.defer()
  ctx = audioStream.ctx
  console.log globalBuffer, buffers
  newSource = ctx.createBufferSource()
  newSource.buffer = globalBuffer
  newSource.connect ctx.destination
  onStateChnageCallback = (e) ->
    if e.data is 1
      newSource.start 0
      deferred.resolve()
  player.seekTo 0
  player.playVideo()
  return deferred.promise

globalBuffer = null

mergeToGlobalBuffer = (buffers) ->
  console.log buffers
  ctx = audioStream.ctx
  buffer = ctx.createBuffer 2, buffers[0].length, ctx.sampleRate
  (buffer.getChannelData 0).set buffers[0]
  (buffer.getChannelData 1).set buffers[1]
  if globalBuffer
    globalBuffer = mergeBuffers [
      globalBuffer
      buffer
    ], ctx
  else
    globalBuffer = buffer
  return Q.when globalBuffer

###
audioStream.getSourceStream()
.then playAndRecord
.then getBuffers
.then mergeToGlobalBuffers
.then playBufferWithVideo
.then () ->
  'do`nathing'
###


audioStream.getSourceStream()
.then initRecorder
.then (recorder) ->
  buttonRecord.addEventListener 'click', ->
    playAndRecord recorder
    .catch (e) ->
      console.log e

  buttonStop.addEventListener 'click', ->
    stopRecord recorder
    getBuffers recorder
    .then mergeToGlobalBuffer
    .then playBufferWithVideo
    .catch (e) ->
      console.log e
