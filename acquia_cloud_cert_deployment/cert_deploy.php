#!/usr/bin/env php
<?php

require_once 'vendor/autoload.php';

use Acquia\Hmac\Guzzle\HmacAuthMiddleware;
use Acquia\Hmac\Key;
use GuzzleHttp\Client;
use GuzzleHttp\HandlerStack;
use Commando\Command;
use GuzzleHttp\Exception\ClientException;

$cmd = new Commando\Command();

// Define script arguments

$cmd->option()
  ->require()
  ->referredToAs('Environment ID')
  ->describedAs('Environment ID. Can be found in the link to environment on application page.');

$cmd->option()
  ->require()
  ->describedAs('Private keyfile path')
  ->referredToAs('KEYFILE')
  ->expectsFile();

$cmd->option()
  ->require()
  ->describedAs('Full certificate chain path')
  ->referredToAs('FULLCHAINFILE')
  ->expectsFile();

$cmd->option()
  ->require()
  ->describedAs('Intermediate certificates path')
  ->referredToAs('CHAINFILE')
  ->expectsFile();

$cmd->option()
  ->require()
  ->referredToAs('Timestamp')
  ->describedAs('Timestamp of sitemap creation');

$cmd->option("a")
  ->aka('activate')
  ->describedAs('Activate the deployed certificate.')
  ->boolean();

$cmd->option("p")
  ->aka('label-prefix')
  ->describedAs('Optionally specify a label prefix. Defaults to \'cert\'');

list($environment_id, $keyfile_path, $full_certificate_chain_path, $intermediate_certificates, $timestamp) = $cmd;

// Format timestamp as ISO 8601 date
$timestamp_formatted = gmdate('c', $timestamp);

$secrets = extract_secrets($cmd);

// Create the HTTP HMAC key.
$key = new Key($secrets['token'], $secrets['secret']);

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

$base_url = 'https://cloud.acquia.com/api/';
// Create label beforehand, so it can be used at multiple places.
if ($label_prefix = $cmd['label-prefix']) {
    $label = "{$label_prefix}_{$timestamp_formatted}";
} else {
  $label = "cert_{$timestamp_formatted}";
}

// Request.
try {

  $api_method = "environments/{$environment_id}/ssl/certificates";
  $response = $client->request('POST', $base_url . $api_method, [
    'form_params' => [
      'certificate' => file_get_contents($full_certificate_chain_path),
      'private_key' => file_get_contents($keyfile_path),
      'ca_certificates' => file_get_contents($intermediate_certificates),
      'label' => $label,
    ],
  ]);
} catch (ClientException $e) {
    print $e->getMessage();
    print_response_message($e->getResponse(), $cmd);
}

print_response_message($response->getBody(), $cmd);

if ($response->getStatusCode() == 202 && $cmd['activate']) {
  // Get all  certificates
  $certificates = get_deployed_certificates($environment_id, $client, $base_url, $cmd);
  // Activate it
  // Loop through the certificates, get ID of the one which has the same Label as the current one
  if (is_array($certificates)) {
    foreach ($certificates as $cert_id => $cert_label) {
      // $label is the label of currently deployed certificate
      if ($label === $cert_label) {
        // Request.
        try {
          $api_method = "environments/{$environment_id}/ssl/certificates/{$cert_id}/actions/activate";
          $response = $client->request('POST', $base_url . $api_method, []);
        } catch (ClientException $e) {
            print $e->getMessage();
            print_response_message($e->getResponse(), $cmd);
        }
        print_response_message($response->getBody(), $cmd);
      }
    }
  }
}

/**
 * Helper function, which extracts saved secrets from secrets.settings.php file.
 */
function extract_secrets($cmd) {
  // Load Acquia Cloud secrets file
  $secrets_file = sprintf('%s/letsencrypt_drupal_config/%s.%s/secrets.settings.php',$_ENV['HOME'], $_ENV['AH_SITE_GROUP'], $_ENV['AH_SITE_ENVIRONMENT']);

  if (!file_exists($secrets_file)) {
    $cmd->error(new Exception('The secrets file wasn\'t found. Please read https://docs.acquia.com/resource/secrets/ and create one.'));
  }

  require $secrets_file;

  if (!isset($acquia_cloud_token, $acquia_cloud_secret)) {
    $cmd->error(new Exception('The script needs variables $acquia_cloud_token and $acquia_cloud_secret defined in the secrets.settings.php file.'));
  }

  return [
    'token' => $acquia_cloud_token,
    'secret' => $acquia_cloud_secret,
  ];
}

/**
 * Helper function, returns array of deployed certificates, keyed by
 * certificate ID.
 *
 * @param $environment_id
 * @param $client
 * @param $base_url
 * @param $cmd
 *
 * @return array
 */
function get_deployed_certificates($environment_id, $client, $base_url, $cmd) {
  // Request.
  try {
    $api_method = "environments/{$environment_id}/ssl/certificates";
    $response = $client->request('GET', $base_url . $api_method, []);
  } catch (ClientException $e) {
        $cmd->error($e->getMessage());
  }

  if ($deployed_certificates = json_decode($response->getBody(), TRUE)) {
    $certificates_map = [];
    foreach ($deployed_certificates['_embedded']['items'] as $item) {
      $certificates_map[$item['id']] = $item['label'];
    }
    return $certificates_map;
  }
}

/**
 * Prints response from Acquia Cloud API.
 *
 * @param $response_body
 * @param $cmd
 */
function print_response_message($response_body, $cmd) {
  $response_body = json_decode($response_body, TRUE);

  if (array_key_exists('error', $response_body)) {
    $cmd->error(new Exception($response_body['message']));
  }

  print $response_body['message'] . PHP_EOL;
}
