/**
 * Created by Ben on 8/19/2025.
 */

global class RecipeRunner implements Queueable,Database.AllowsCallouts {
    public String recipeId;
    public Datetime startTime=Datetime.newInstance(System.now().date(),Time.newInstance(9,30,00,000));
    public Datetime stopTime=startTime.addHours(10);
    public Integer periods=60;//every 10min over 10 hours would be 60
    public Integer minInterval=10;
    public Boolean manual=false;
    private static final String baseUrl=Url.getOrgDomainUrl().toExternalForm()+'/services/data/v64.0/wave/';
    public RecipeRunner(String recipeId){ // this is the default reschedule constructor. scheduled hours of running in ca
        this.recipeId=recipeId; //this is the one to manually plug-in the recipeid
    }
    public RecipeRunner(String recipeId,Datetime startTime,Datetime stopTime,Integer periods){
        this.recipeId=recipeId; //this is the one to manually plug-in the recipeid
        this.startTime=startTime;
        this.stopTime=stopTime;
        this.periods=periods;
        this.minInterval=((((stopTime.getTime()+59999)-startTime.getTime())/60000)/periods).intValue(); //Integer mins=1+((stopTime.-startTime)/this.periods);
        this.manual=true;
    }
    public RecipeRunner(){
        this.recipeId=RecipeRunnerSchedulable_Setting__mdt.getInstance('Current').RecipeId__c;
    }//for scheduleable;
    public static String getTargetDataflowId(String recipeId){
        HttpRequest req=new HttpRequest();
        req.setEndpoint(baseUrl+'recipes/'+recipeId+'?format=R3');//   http://bristolnebraska.my.salesforce.com/services/data/v64.0/wave/recipes/0x4000191a2aJzQo1B/jobs;
        req.setMethod('GET');
        req.setHeader('Content-Type','application/json');
        req.setHeader('Authorization','Bearer '+UserInfo.getSessionId());
        Http http=new Http();
        HttpResponse res=http.send(req);
        System.debug('—–Response—>\n'+res.toString());
        String targetId;
        if(res.getStatusCode()>=200&&res.getStatusCode()<300){
            System.debug('successful Id swap.');
            targetId=String.valueOf(((Map<String,Object>)JSON.deserializeUntyped(res.getBody())).get('targetDataflowId'));
        } else {
            System.debug('NO! RECIPE ID NOT RIGHT!!'+res.getStatus()+' '+res.getBody());
        }
        return targetId;
    }
    public static String postRecipeRunRequest(String targetDataflowId){
        HttpRequest req=new HttpRequest();
        req.setEndpoint(baseUrl+'dataflowjobs');
        req.setMethod('POST');
        req.setBody('{"dataflowId":"'+targetDataflowId+'","command":"start"}');
        req.setHeader('Content-Type','application/json');
        req.setHeader('Authorization','Bearer '+UserInfo.getSessionId());
        Http http=new Http();
        HttpResponse res=http.send(req);
        String jobId;
        if(res.getStatusCode()>=200&&res.getStatusCode()<300){
            System.debug('\r\rsuccessfully queued.\r\t'+baseUrl);
            jobId=String.valueOf(((Map<String,Object>)JSON.deserializeUntyped(res.getBody())).get('Id'));
        } else {
            System.debug('something is wrong!!! \n\n'+JSON.serializePretty(res.getBody()));
        }
        return jobId;
    }
    public void execute(QueueableContext qc) { // you can't change the name Current
        HttpRequest req=new HttpRequest();
        String targetId=getTargetDataflowId(this.recipeId);
        if(targetId!=null){
            String dataflowJobId=postRecipeRunRequest(targetId);
            if(dataflowJobId!=null){
                System.debug('\rSuccess\r\t'+baseUrl+'dataflowjobs/030R700000Ms4TOIAZ');
            } else {
                System.debug('This sucks');
            }
        }
        Datetime nextTime=Datetime.now().addMinutes(this.minInterval);
        if(nextTime>=this.startTime&&nextTime<this.stopTime){ //resched cron triggers arent recurring, they go on their specific time and are gone.
            String cron=+'0 '+nextTime.minute()+' '+nextTime.hour()+' '+nextTime.day()+' '+nextTime.month()+' ? '+nextTime.year();
            Integer runX=(((1+((nextTime.hour()*60)+nextTime.minute()))-(this.startTime.hour()*60)+this.startTime.addSeconds(59).minute())/this.minInterval);
            System.debug('r='+runX+'/'+this.periods);
            RecipeRunnerSchedulable reRunner;
            if(this.manual){
                reRunner=new RecipeRunnerSchedulable(this.recipeId,this.startTime,this.stopTime,this.periods);
            } else {
                reRunner=new RecipeRunnerSchedulable(this.recipeId);
            }
            System.schedule('RapidReporter['+runX+'/'+this.periods+'] '+nextTime.format('EE, M/d h:mma'),cron,reRunner);
        }   //probably put call_log__c delete stuff here too.
    }
}
/* ANONYMOUS STUFF:
    //delete cronTriggers:
        List<CronTrigger> crons=[SELECT Id,CronExpression,NextFireTime,PreviousFireTime,CreatedDate FROM CronTrigger WHERE CronExpression LIKE'%0 1-2 * * ?' AND CronExpression LIKE '0 %'];
        System.debug(JSON.serializePretty(crons));
        for(CronTrigger cron : crons){
            System.abortJob(cron.Id);
        }
    //create new cronTriggers:
        RecipeRunner rr=new RecipeRunner();
        System.schedule('Recipe Run(:00s) 9AM-7PM','0 00 1-2 * * ?', new RecipeRunner());
        System.schedule('Recipe Run(:10s) 9AM-7PM','0 10 1-2 * * ?', new RecipeRunner());
        System.schedule('Recipe Run(:20s) 9AM-7PM','0 20 1-2 * * ?', new RecipeRunner());
        System.schedule('Recipe Run(:30s) 9AM-7PM','0 30 1-2 * * ?', new RecipeRunner());
        System.schedule('Recipe Run(:40s) 9AM-7PM','0 40 1-2 * * ?', new RecipeRunner());
        System.schedule('Recipe Run(:50s) 9AM-7PM','0 50 1-2 * * ?', new RecipeRunner());

*/