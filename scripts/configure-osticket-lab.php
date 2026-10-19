<?php
if(PHP_SAPI!=='cli'){http_response_code(403);exit;}
$_SERVER['HTTP_HOST']='helpdesk.corp.example.test';
$_SERVER['REMOTE_ADDR']='127.0.0.1';
$_SERVER['REQUEST_METHOD']='GET';
$_SERVER['SCRIPT_NAME']='/scp/index.php';
chdir('/var/www/osticket');require 'main.inc.php';
$thisstaff=Staff::lookup(1);
$cfg->set('enable_kb',1);
// These simulated .test requesters intentionally have no external MX/mailbox.
$cfg->set('verify_email_addrs',0);
$cfg->set('helpdesk_url','https://helpdesk.corp.example.test/');
$seed=json_decode(file_get_contents('/home/labadmin/ticket-seed.json'),true);
$manifest=json_decode(file_get_contents('/root/lab-secrets/ticket-manifest.json'),true);
$topics=[];
$form=DynamicForm::objects()->filter(['type'=>'T'])->first();
foreach(['Login','DNS Issues','Connectivity','File Access'] as $name){
    $topic=Topic::lookup(Topic::getIdByName($name,0)) ?: Topic::create();
    $errors=[];
    $vars=['id'=>$topic->getId() ?: 0,'topic'=>$name,'topic_pid'=>0,'dept_id'=>1,'priority_id'=>2,'status_id'=>1,'sla_id'=>1,'page_id'=>0,'ispublic'=>1,'status'=>'active','noautoresp'=>1,'notes'=>'Isolated lab practice; no outgoing mail configured.','forms'=>[$form->getId()],'assign'=>''];
    if(!$topic->update($vars,$errors)){throw new Exception(json_encode($errors).' Database: '.db_error());}
    $topics[$name]=$topic;
}
foreach($manifest as $row){
    $source=array_values(array_filter($seed,fn($x)=>$x['exercise']===$row['exercise']))[0];
    $name=$source['category']==='DNS'?'DNS Issues':$source['category'];
    $ticket=Ticket::lookup($row['ticket_id']);
    $ticket->topic_id=$topics[$name]->getId();
    if(!$ticket->save()){throw new Exception('Could not classify '.$row['exercise']);}
}
echo 'Configured four help topics, internal HTTPS URL and enabled KB; unverified FAQs remain private.'.PHP_EOL;
