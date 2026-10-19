<?php
// Run as root on HD01, against this disposable lab only. Uses osTicket model validation.
if (PHP_SAPI !== 'cli') { http_response_code(403); exit; }
$_SERVER['HTTP_HOST'] = 'helpdesk.corp.example.test';
$_SERVER['SERVER_NAME'] = 'helpdesk.corp.example.test';
$_SERVER['REMOTE_ADDR'] = '127.0.0.1';
$_SERVER['REQUEST_METHOD'] = 'GET';
$_SERVER['SCRIPT_NAME'] = '/scp/index.php';
chdir('/var/www/osticket');
require 'main.inc.php';
require_once INCLUDE_DIR.'class.faq.php';
require_once INCLUDE_DIR.'class.category.php';
$input = $argv[1] ?? '/home/labadmin/ticket-seed.json';
$manifestPath = '/root/lab-secrets/ticket-manifest.json';
$items = json_decode(file_get_contents($input), true, 512, JSON_THROW_ON_ERROR);
$categories = [];
$manifest = file_exists($manifestPath) ? json_decode(file_get_contents($manifestPath), true) : [];
foreach ($items as $item) {
    if (array_filter($manifest, fn($row) => $row['exercise'] === $item['exercise'])) { continue; }
    $name = 'Lab Drafts - '.$item['category'];
    if (!isset($categories[$name])) {
        $category = Category::lookup(Category::findIdByName($name)) ?: Category::create();
        $errors = [];
        $vars = ['id'=>$category->getId() ?: 0, 'name'=>$name, 'description'=>'Unverified expected lab solutions. Publish only after live validation.', 'ispublic'=>0, 'pid'=>0, 'notes'=>'Created as private drafts for lab practice.'];
        if (!$category->update($vars, $errors)) { throw new Exception(json_encode($errors)); }
        $categories[$name] = $category->getId();
    }
    $errors = [];
    $title = $item['kb'].' - '.$item['title'];
    $faq = FAQ::lookup(FAQ::findIdByQuestion($title)) ?: FAQ::create();
    $body = '<p><strong>DRAFT - Expected solution; live verification pending.</strong></p><pre>'.htmlspecialchars($item['expected_article'], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8').'</pre>';
    $vars = ['id'=>$faq->getId() ?: 0, 'question'=>$title, 'category_id'=>$categories[$name], 'answer'=>$body, 'ispublished'=>0, 'notes'=>'Do not claim this scenario resolved until actual diagnostics and retest are recorded.', 'topics'=>[]];
    if (!$faq->update($vars, $errors)) { throw new Exception(json_encode($errors)); }
    $errors = [];
    $user = User::fromVars(['name'=>'Lab '.$item['user'], 'email'=>$item['user'].'@corp.example.test']);
    if (!$user) { throw new Exception('Could not provision simulated requester '.$item['user']); }
    $ticketVars = ['name'=>'Lab '.$item['user'], 'email'=>$item['user'].'@corp.example.test', 'subject'=>$item['exercise'].' - '.$item['title'], 'message'=>'Simulated support exercise. Pending live fault injection, diagnostic evidence and resolution verification. A private expected-solution draft exists as '.$item['kb'].'.', 'topicId'=>1, 'source'=>'API'];
    $ticketVars['uid'] = $user->getId();
    $ticket = Ticket::create($ticketVars, $errors, 'api', false, false);
    if (!$ticket) { throw new Exception(json_encode($errors)); }
    $manifest[] = ['exercise'=>$item['exercise'], 'ticket_id'=>$ticket->getId(), 'ticket_number'=>$ticket->getNumber(), 'faq_id'=>$faq->getId(), 'ticket_status'=>'open', 'faq_status'=>'private draft', 'verified'=>false];
    file_put_contents($manifestPath, json_encode($manifest, JSON_PRETTY_PRINT));
    chmod($manifestPath, 0600);
}
echo 'Created '.count($manifest).' open exercise tickets and private draft FAQs; no resolutions claimed.'.PHP_EOL;
