<?php
// Close/publish only exercises backed by observed fault and successful retest records.
if (PHP_SAPI !== 'cli') { http_response_code(403); exit; }
$_SERVER['HTTP_HOST']='helpdesk.corp.example.test';
$_SERVER['REMOTE_ADDR']='127.0.0.1';
$_SERVER['REQUEST_METHOD']='GET';
$_SERVER['SCRIPT_NAME']='/scp/index.php';
chdir('/var/www/osticket');
require 'main.inc.php';
require_once INCLUDE_DIR.'class.faq.php';
require_once INCLUDE_DIR.'class.category.php';
$thisstaff=Staff::lookup(1);
if (!$thisstaff || !$thisstaff->isAdmin()) { throw new Exception('Expected lab administrator missing.'); }
$results=json_decode(file_get_contents($argv[1]),true,512,JSON_THROW_ON_ERROR);
$manifestPath='/root/lab-secrets/ticket-manifest.json';
$manifest=json_decode(file_get_contents($manifestPath),true,512,JSON_THROW_ON_ERROR);
$closed=TicketStatus::objects()->filter(['state'=>'closed'])->first();
if (!$closed) { throw new Exception('No closed status configured.'); }
foreach ($results as $result) {
    if (($result['fault_observed'] ?? false) !== true || ($result['repair_verified'] ?? false) !== true || ($result['baseline_restored'] ?? false) !== true) {
        throw new Exception('Missing observed fault/repair/restoration evidence for '.$result['exercise']);
    }
    foreach (['symptom','cause','resolution','verification','evidence','client_guidance'] as $field) {
        if (empty($result[$field])) { throw new Exception('Missing '.$field); }
    }
    foreach ($manifest as &$entry) {
        if ($entry['exercise'] !== $result['exercise']) { continue; }
        if (!empty($entry['verified'])) { break; }
        $ticket=Ticket::lookup($entry['ticket_id']);
        $faq=FAQ::lookup($entry['faq_id']);
        if (!$ticket || !$faq || strpos($ticket->getSubject(),$entry['exercise'].' ') !== 0) { throw new Exception('Record identity mismatch.'); }
        $errors=[];
        $note='LIVE LAB VALIDATION'.PHP_EOL.json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        if (!$ticket->postNote(['title'=>'Verified lab resolution','note'=>$note],$errors,$thisstaff,false)) { throw new Exception(json_encode($errors)); }
        if (!$ticket->setStatus($closed,'Live fault reproduced, repaired, retested and baseline restored.',$errors)) { throw new Exception(json_encode($errors)); }
        $category=$faq->getCategory();
        $errors=[];
        if (!$category->update(['id'=>$category->getId(),'name'=>str_replace('Lab Drafts - ','Lab - ',$category->getName()),'description'=>'Solutions validated in the isolated Windows Administration lab.','ispublic'=>1,'pid'=>0,'notes'=>'Live validation references recorded in linked tickets.'],$errors)) { throw new Exception(json_encode($errors)); }
        $answer='';
        foreach (['symptom'=>'Symptom','cause'=>'Cause','resolution'=>'Resolution','client_guidance'=>'What you can do','verification'=>'Verified outcome'] as $field=>$label) {
            $answer.='<p><strong>'.$label.':</strong> '.htmlspecialchars($result[$field],ENT_QUOTES|ENT_SUBSTITUTE,'UTF-8').'</p>';
        }
        $errors=[];
        if (!$faq->update(['id'=>$faq->getId(),'question'=>$faq->getQuestion(),'category_id'=>$category->getId(),'answer'=>$answer,'ispublished'=>1,'notes'=>$note,'topics'=>[]],$errors)) { throw new Exception(json_encode($errors)); }
        $entry['ticket_status']='closed';
        $entry['faq_status']='published';
        $entry['verified']=true;
        $entry['verified_at']=date(DATE_ATOM);
        file_put_contents($manifestPath,json_encode($manifest,JSON_PRETTY_PRINT));
        chmod($manifestPath,0600);
        echo $entry['exercise'].' closed; FAQ '.$entry['faq_id'].' published'.PHP_EOL;
        break;
    }
    unset($entry);
}
