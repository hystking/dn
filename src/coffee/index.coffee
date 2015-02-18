
param = (require "site-param")()
_ = require "lodash"
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
    height: 320
    width: 480
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

playBufferWithVideo = (buffer) ->
  deferred = Q.defer()
  ctx = audioStream.ctx
  newSource = ctx.createBufferSource()
  newSource.buffer = buffer
  newSource.connect ctx.destination
  onStateChnageCallback = (e) ->
    if e.data is 1
      console.log player.getCurrentTime()
      newSource.start 0
      deferred.resolve()
  player.seekTo 0
  player.playVideo()
  return deferred.promise

globalBuffer = null

getMergeBuffer = (buffers) ->
  console.log buffers
  ctx = audioStream.ctx
  buffer = ctx.createBuffer 2, buffers[0].length, ctx.sampleRate
  (buffer.getChannelData 0).set buffers[0]
  (buffer.getChannelData 1).set buffers[1]
  if globalBuffer
    mergedBuffer = mergeBuffers [
      globalBuffer
      buffer
    ], ctx
  else
    mergedBuffer = buffer
  return Q.when mergedBuffer

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

  buttonSave.addEventListener 'click', ->
    getBuffers recorder
    .then getMergeBuffer
    .then (mergedBuffer) ->
      globalBuffer = mergedBuffer
    .catch (e) ->
      console.log e
  
  buttonStop.addEventListener 'click', ->
    stopRecord recorder

  buttonPreview.addEventListener 'click', ->
    getBuffers recorder
    .then getMergeBuffer
    .then playBufferWithVideo
    .catch (e) ->
      console.log e
  
  buttonDownload.addEventListener 'click', ->
    console.log globalBuffer


    recLength = globalBuffer.length
    sampleRate = globalBuffer.sampleRate
    numChannels = globalBuffer.numberOfChannels
    recBuffers = _.map [0...numChannels], (ch) -> globalBuffer.getChannelData ch
    try
      localStorage.dragonWAV = JSON.stringify recBuffers
    catch e
      console.log 'fail with save to localStorage'
    `
function init(config){
  sampleRate = config.sampleRate;
  numChannels = config.numChannels;
  initBuffers();
}

function record(inputBuffer){
  for (var channel = 0; channel < numChannels; channel++){
    recBuffers[channel].push(inputBuffer[channel]);
  }
  recLength += inputBuffer[0].length;
}

function exportWAV(type){
  var buffers = [];
  for (var channel = 0; channel < numChannels; channel++){
    //buffers.push(mergeBuffers(recBuffers[channel], recLength));
    buffers.push(recBuffers[channel]);
  }
  if (numChannels === 2){
      var interleaved = interleave(buffers[0], buffers[1]);
  } else {
      var interleaved = buffers[0];
  }
  var dataview = encodeWAV(interleaved);
  console.log('1');
  var audioBlob = new Blob([dataview], { type: type });
  console.log('2');

  return audioBlob;
  //this.postMessage(audioBlob);
}

function getBuffer(){
  var buffers = [];
  for (var channel = 0; channel < numChannels; channel++){
    buffers.push(mergeBuffers(recBuffers[channel], recLength));
  }
  this.postMessage(buffers);
}

function clear(){
  recLength = 0;
  recBuffers = [];
  initBuffers();
}

function initBuffers(){
  for (var channel = 0; channel < numChannels; channel++){
    recBuffers[channel] = [];
  }
}

function mergeBuffers(recBuffers, recLength){
  var result = new Float32Array(recLength);
  var offset = 0;
  for (var i = 0; i < recBuffers.length; i++){
    console.log(recBuffers, recBuffers[i], offset);
    result.set(recBuffers[i], offset);
    offset += recBuffers[i].length;
  }
  return result;
}

function interleave(inputL, inputR){
  var length = inputL.length + inputR.length;
  var result = new Float32Array(length);

  var index = 0,
    inputIndex = 0;

  while (index < length){
    result[index++] = inputL[inputIndex];
    result[index++] = inputR[inputIndex];
    inputIndex++;
  }
  return result;
}

function floatTo16BitPCM(output, offset, input){
  for (var i = 0; i < input.length; i++, offset+=2){
    var s = Math.max(-1, Math.min(1, input[i]));
    output.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
  }
}

function writeString(view, offset, string){
  for (var i = 0; i < string.length; i++){
    view.setUint8(offset + i, string.charCodeAt(i));
  }
}

function encodeWAV(samples){
  var buffer = new ArrayBuffer(44 + samples.length * 2);
  var view = new DataView(buffer);

  /* RIFF identifier */
  writeString(view, 0, 'RIFF');
  /* RIFF chunk length */
  view.setUint32(4, 36 + samples.length * 2, true);
  /* RIFF type */
  writeString(view, 8, 'WAVE');
  /* format chunk identifier */
  writeString(view, 12, 'fmt ');
  /* format chunk length */
  view.setUint32(16, 16, true);
  /* sample format (raw) */
  view.setUint16(20, 1, true);
  /* channel count */
  view.setUint16(22, numChannels, true);
  /* sample rate */
  view.setUint32(24, sampleRate, true);
  /* byte rate (sample rate * block align) */
  view.setUint32(28, sampleRate * 4, true);
  /* block align (channel count * bytes per sample) */
  view.setUint16(32, numChannels * 2, true);
  /* bits per sample */
  view.setUint16(34, 16, true);
  /* data chunk identifier */
  writeString(view, 36, 'data');
  /* data chunk length */
  view.setUint32(40, samples.length * 2, true);

  floatTo16BitPCM(view, 44, samples);

  return view;
}
    `
    blob = exportWAV 'audio/wav'
    Recorder.forceDownload blob
