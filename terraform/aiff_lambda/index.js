const AWS = require('aws-sdk');
const ffmpeg = require('fluent-ffmpeg');
const stream = require('stream');
const URI = require('uri-js');

if (process.env["AWS_S3_ENDPOINT"]) {
  AWS.config.s3 = {
    endpoint: process.env["AWS_S3_ENDPOINT"],
    s3ForcePathStyle: true,
  };
}

const aiff2wav = async (source, dest) => {
  const s3Source = parseS3Uri(source);
  const s3Dest = parseS3Uri(dest);
  const S3 = new AWS.S3();

  const sourceStream = S3.getObject(s3Source).createReadStream();
  const { writeStream, promise } = uploadStream(s3Dest);

  console.log(`Reformatting ${source} to ${dest}`);

  sourceStream
    .on('end', () => console.log('SOURCE', 'Stream ended'))
    .on('error', (err) => {
      console.error('STREAM', err.message);
      throw err;
    });

  ffmpeg(sourceStream)
    .inputFormat('aiff')
    .audioCodec('copy')
    .outputFormat('wav')
    .on('end', () => console.log('FFMPEG', 'Stream ended'))
    .on('error', (err) => {
      console.error('FFMPEG', err.message);
      throw err;
    })
    .pipe(writeStream, {end: true});

  await promise;
}

const parseS3Uri = (s3Uri) => {
  const uri = URI.parse(s3Uri);
  return { 
    Bucket: uri.host, 
    Key: uri.path.replace(/^\/+/, "")
  }
}

const uploadStream = ({ Bucket, Key }) => {
  const s3 = new AWS.S3();
  const pass = new stream.PassThrough();
  return {
    writeStream: pass,
    promise: s3.upload({ Bucket, Key, Body: pass }).promise(),
  };
}

const lambdaHandler = async (event) => {
  return aiff2wav(event.source, event.dest);
}

module.exports = { 
  aiff2wav: aiff2wav, 
  handler: lambdaHandler 
}