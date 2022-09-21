/**
 * Schedulable class to retrieve external User Stories on a scheduled basis.
 *
 * @author Ümit Can Uçkan
 * @lastModifiedBy Kunal Kaushik
 * @version 2.0
 * @since CCM Integrations 1.0
 */
global with sharing class ScheduleUserStoryFetch implements Schedulable {
    final String VSTS = 'Visual Studio Team Services';
    final String defaultCronExp = '0 0 12 * * ?';
    copado__Project__c project;
    Boolean isSprint;
    Boolean isBulkSprint;
    Integer chunkSize;
    String pId;
    global ScheduleUserStoryFetch(Id pId, Boolean isSprint) {
        this.isSprint = isSprint;
        this.pId = pId;
        this.project = [
            SELECT
                Id,
                Name,
                Copado_Integration_Setting__r.External_System__c,
                Copado_Integration_Setting__r.Named_Credential__c,
                JQL_Extended_Filter__c,
                Enable_Logs__c,
                Team_Info__c,
                Project_External_Id__c,
                Workspace_Id__c,
                Sprint_Per_Batch_Chunk_Size__c
            FROM copado__Project__c
            WHERE Id = :pId
        ];
        if (null != project.Sprint_Per_Batch_Chunk_Size__c) {
            this.chunkSize = Integer.valueOf(project.Sprint_Per_Batch_Chunk_Size__c);
        } else {
            this.chunkSize = 50;
        }
    }

    public void prepareSprints() {
        IntegrationFactory.returnInstance(project.Copado_Integration_Setting__r.External_System__c).fetchSprints(project);
    }

    /**
     * @desc : This method is used for scheduling the sync of User Stories and Sprints into Salseforce Org
     * Project from 3rd party application.
     * @param scheduledClass : instance of ScheduleUserStoryFetch Class
     * @param cronExp : cron expression which will be used to schedule the sync, if provided as NULL then sync will
     * happen everyday at 12pm.
     */
    global void scheduleSyncForUserStoriesAndSprintsFromThridParty(ScheduleUserStoryFetch scheduledClass, String cronExp){
        if(scheduledClass.isSprint){
           scheduledClass.prepareSprints();
        }
        if(String.isBlank(cronExp)){
            // if no value is provided for cronExp then the sync will happen everyday at 12pm
            cronExp = defaultCronExp;
        }
        try{
            String scheduleJobId = system.schedule('Scheduled User Story and Sprint sync..', cronExp, scheduledClass);
        }
        catch(Exception ex){
            throw new ApplicationException(Label.InvalidInputParameter);
        }
        
    }

    global void execute(SchedulableContext sc) {
        if (isSprint) {
            List<copado__Sprint__c> sprints = [
                SELECT Id, Name, External_Id__c
                FROM copado__Sprint__c
                WHERE copado__Project__c = :pId AND External_Id__c != NULL
                ORDER BY copado__Start_Date__c ASC
            ];
            if (null != sprints && !sprints.isEmpty() && sprints.size() >= chunkSize) {
                this.isBulkSprint = true;
            } else {
                this.isBulkSprint = false;
            }
        }
        if (isSprint && isBulkSprint) {
            Database.executeBatch(new ExecuteUserStoryFetch(project), chunkSize);
        } else {
            if(project.Copado_Integration_Setting__r.External_System__c == VSTS && !isSprint){
                Database.executeBatch(new ExecuteWorkItemIdsFetch(project, false), 1);
            } else {
                Database.executeBatch(new ExecuteUserStoryUpsert(project, isSprint), 200);
            }
        }
    }
    public class ApplicationException extends Exception {}
}