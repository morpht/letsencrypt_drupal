#!/usr/bin/env php
<?php

require_once 'vendor/autoload.php';

use Acquia\Hmac\Guzzle\HmacAuthMiddleware;
use Acquia\Hmac\Key;
use GuzzleHttp\Client;
use GuzzleHttp\HandlerStack;
use Commando\Command;

$cert_deploy = new Commando\Command();

// Define script arguments

$cert_deploy->option()
  ->require()
  ->referredToAs('Environment ID')
  ->describedAs('Environment ID. Can be found in the link to environment on application page.');

$cert_deploy->option()
  ->require()
  ->describedAs('Private keyfile path')
  ->referredToAs('KEYFILE')
  ->expectsFile();

$cert_deploy->option()
  ->require()
  ->describedAs('Full certificate chain path')
  ->referredToAs('FULLCHAINFILE')
  ->expectsFile();

$cert_deploy->option()
  ->require()
  ->describedAs('Intermediate certificates path')
  ->referredToAs('CHAINFILE')
  ->expectsFile();

$cert_deploy->option()
  ->require()
  ->referredToAs('Timestamp')
  ->describedAs('Timestamp of sitemap creation');

list($environment_id, $keyfile_path, $full_certificate_chain_path, $intermediate_certificates, $timestamp) = $cert_deploy;

// Format timestamp
$timestamp_formatted = gmdate('d-m-Y H:i:s', $timestamp);

// Load Acquia Cloud secrets file
$secrets_file = sprintf('/mnt/files/%s.%s/secrets.settings.php', $_ENV['AH_SITE_GROUP'], $_ENV['AH_SITE_ENVIRONMENT']);

if (!file_exists($secrets_file)) {
  print 'The secrets file wasn\'t found. Please read https://docs.acquia.com/resource/secrets/ and create one.' . PHP_EOL;
  exit(1);
}

require $secrets_file;

if (!isset($acquia_cloud_token, $acquia_cloud_secret)) {
    print 'The script needs variables $acquia_cloud_token and $acquia_cloud_secret defined in the secrets.settings.php file.'.PHP_EOL;
    exit(1);
}

// Create the HTTP HMAC key.
$key = new Key($acquia_cloud_token, $acquia_cloud_secret);

// Optionally, you can provide additional headers when generating the signature.
// The header keys need to be provided to the middleware below.
$headers = [];

// Specify the API's realm.
// Consult the API documentation for this value.
$realm = 'Acquia';

// Create a Guzzle middleware to handle authentication during all requests.
// Provide your key, realm and the names of any additional custom headers.
$middleware = new HmacAuthMiddleware($key, $realm, array_keys($headers));

// Register the middleware.
$stack = HandlerStack::create();
$stack->push($middleware);

// Create a client.
$client = new Client([
  'handler' => $stack,
]);

// Request.
try {
  $base_url = 'https://cloud.acquia.com/api/';
  $api_method = "environments/{$environment_id}/ssl/certificates";
  $response = $client->request('POST', $base_url . $api_method, [
    'form_params' => [
      'certificate' => file_get_contents($full_certificate_chain_path),
      'private_key' => file_get_contents($keyfile_path),
      'ca_certificates' => file_get_contents($intermediate_certificates),
      'label' => "Certificate generated at {$timestamp_formatted}"
    ]
  ]);
} catch (ClientException $e) {
  print $e->getMessage();
  $response = $e->getResponse();
}

print $response->getBody(). PHP_EOL;
