#!/usr/bin/env node

const https = require("https");
const fs = require("fs");
const { default: nodeTest } = require("node:test");

const { argv } = process;
const [, , url, path] = argv;

if (url === undefined) {
  process.stderr.write(`The 'url' argument is missing. 
  You need to pass the file url as the first argument`);
  return;
}

if (path === undefined) {
  process.stderr.write(`The 'path' argument is missing. 
  You need to pass the save path as the second argument`);
  return;
}

https.get(url, (res) => {
  const writeStream = fs.createWriteStream(path);

  res.pipe(writeStream);

  writeStream.on("finish", () => {
    writeStream.close();
    process.stderr.write("Download Completed");
  });
});
