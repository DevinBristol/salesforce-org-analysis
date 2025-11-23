/**
 * Created by Ben on 10/3/2025.
 */

global class Five9ReportScheduler implements Schedulable {
    public Id iedId;
    public IntegratedDatasetConfig__c idc;
    public String reportId;//for test bypass. maybe something else.
    public Five9ReportScheduler(Id iedId){
        this.iedId=iedId;
        System.debug('\nFive9ReportScheduler Constructor: this.iedId='+iedId);
    }
    global void execute(SchedulableContext sc) {
        System.enqueueJob(new Five9ReportManager(this.iedId));
    }
}
    /*
        ied not made-–—>    CREATE  #1 (endStamp,startStamp,folderName,reportName,datasetName,datasetLabel,datasetApp,adjMap,cols));
        for restarts—-–>    FLEX    #2 (endStamp,startStamp,folderName,reportName,datasetName,datasetLabel,datasetApp,operation,adjMap,cols));
        to edit meta——->    UPDATE  #3 (endStamp,startStamp,folderName,reportName,datasetName,operation,adjMap));
        once working-–—>    COPYCAT #4 (endStamp,startStamp,folderName,reportName,datasetName));
        reportrunner—-–>
       _process data——->
     */
    //  public Time dayStart=Time.newInstance(5, 30, 0, 0);
   //   public Time dayStop =Time.newInstance(20, 30, 0, 0);
  //    public Integer minuteInterval=10;
 //
/*

 */