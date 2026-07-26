<?php

$socket = @fsockopen(
    '127.0.0.1',
    80,
    $errorCode,
    $errorMessage,
    3
);

if ($socket === false) {
    fwrite(
        STDERR,
        "healthcheck: Apache connection failed: {$errorMessage} ({$errorCode})\n"
    );
    exit(1);
}

$request = "GET / HTTP/1.1\r\n"
    . "Host: localhost\r\n"
    . "Connection: close\r\n"
    . "User-Agent: TravianZ-Docker-Healthcheck\r\n"
    . "\r\n";

fwrite($socket, $request);
stream_set_timeout($socket, 3);

$statusLine = fgets($socket);
$metadata = stream_get_meta_data($socket);

fclose($socket);

if ($metadata['timed_out']) {
    fwrite(STDERR, "healthcheck: Apache response timed out\n");
    exit(1);
}

if (
    !is_string($statusLine)
    || !preg_match('/^HTTP\/\d(?:\.\d)?\s+(\d{3})\b/', $statusLine, $matches)
) {
    fwrite(STDERR, "healthcheck: invalid HTTP response\n");
    exit(1);
}

$statusCode = (int) $matches[1];

if ($statusCode < 200 || $statusCode >= 400) {
    fwrite(
        STDERR,
        "healthcheck: unexpected HTTP status {$statusCode}\n"
    );
    exit(1);
}

exit(0);
