param = (require "site-param")()
Q = require "q"
AudioStream = require "./module/audio-stream"

audioStream = new AudioStream

audioStream.getSourceStream()

.then (stream) ->
  deferred = Q.defer()
  recorder = new Recorder stream,
    workerPath: "js/lib/recorder/recorderWorker.js"
  recorder.record()
  setTimeout ->
    deferred.resolve recorder
  , 30000
  return deferred.promise

.then (recorder) ->
  deferred = Q.defer()
  recorder.stop()
  recorder.getBuffer (buffers) ->
    deferred.resolve buffers
  return deferred.promise

.then (buffers) ->
  console.log buffers
  ctx = audioStream.ctx
  newSource = ctx.createBufferSource()
  newBuffer = ctx.createBuffer 2, buffers[0].length, ctx.sampleRate
  (newBuffer.getChannelData 0).set buffers[0]
  (newBuffer.getChannelData 1).set buffers[1]
  newSource.buffer = newBuffer
  newSource.loop = true

  newSource.connect ctx.destination
  console.log ctx, newSource
  newSource.start 0

.catch (e) ->
  console.log e
