/**
 * Created by Ben on 8/19/2025.
 */

public class RecipeRunnerSchedulable implements Schedulable{
    public RecipeRunner rr;
    public RecipeRunnerSchedulable(){
        this.rr=new RecipeRunner();
    }
    public RecipeRunnerSchedulable(String recipeId){
        this.rr=new RecipeRunner(recipeId);
    }
    public RecipeRunnerSchedulable(String recipeId,Datetime startTime,Datetime stopTime,Integer periods){
        this.rr=new RecipeRunner(recipeId,startTime,stopTime,periods);
    }
    public void execute(SchedulableContext sc) {
        System.enqueueJob(this.rr);
    }
}