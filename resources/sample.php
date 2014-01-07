<?php
// web/index.php

require_once __DIR__.'/../vendor/autoload.php';

$app = new Silex\Application();

// Activate mode debug 
$app['debug'] = true;

$app->get('/hello/{name}', function ($name) use ($app) {
  return 'Hello '.$app->escape($name);
});

$app->get('/', function () use ($app) {
  return 'Initial file. Use in the url hello/your_name. '.$app->escape($name);
});

$app->run();