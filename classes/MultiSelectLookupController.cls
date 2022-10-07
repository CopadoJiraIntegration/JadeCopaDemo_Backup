public with sharing class MultiSelectLookupController {

    @AuraEnabled
    public static ResultWrapper initialRecords(Id userstoryId) {
        List<copado__User_Story__c> userStoryAndReviewers = [
            SELECT
                Id,
                Name,
                Developer_Comments__c,
                (
                    SELECT
                        Id,
                        Name,
                        Comments__c
                    FROM
                        Review_Approvers__r
                    ORDER BY Comments__c DESC
                )
            FROM
                copado__User_Story__c
            WHERE
                Id = :userStoryId
        ];
        List<copado__User_Story__c> userStories = [
            SELECT
                Id,
                Name,
                Developer_Comments__c,
                (
                    SELECT
                        Id,
                        Name,
                        Comments__c
                    FROM
                        Review_Approvers__r
                    ORDER BY Comments__c DESC
                )
            FROM
                copado__User_Story__c
            WHERE
                Id = :userStoryId
        ];
        String reviewerComments = '';
        String developerCommments = '';
        List<SObjectQueryResult> lstReturnResult = new List<SObjectQueryResult>();
        for (copado__User_Story__c userStoryItr : userStories) {
            for (Review_Approver__c reviewItr : userStoryItr.Review_Approvers__r) {
                if (!String.isEmpty(reviewItr.Comments__c)) {
                    reviewerComments = reviewerComments + reviewItr.Comments__c;
                }
                SObjectQueryResult result = new SObjectQueryResult();
                result.recordId = (String) reviewItr.Id;
                result.recordName = reviewItr.Name;
                lstReturnResult.add(result);
            }
            if (!String.isEmpty(userStoryItr.Developer_Comments__c)) {
                developerCommments = developerCommments + userStoryItr.Developer_Comments__c;
            }
        }
        ResultWrapper resultWrapperInstance = new ResultWrapper();
        resultWrapperInstance.sObjectQueryResults = lstReturnResult;
        resultWrapperInstance.developerComments = developerCommments;
        resultWrapperInstance.reviewerComments = reviewerComments;
        return resultWrapperInstance;
    }

    //This method retrieves the data from database table. It search input is '*', then retrieve all records
    @AuraEnabled
    public static ResultWrapper retrieveRecords(String objectName,
                                                    String fieldAPINames,
                                                    String filterFieldAPIName,
                                                    String strInput,
                                                    Id userStoryId){

        List<SObjectQueryResult> lstReturnResult = new List<SObjectQueryResult>();
        if(strInput.equals('*')){
            strInput = '';
        }
        String str = strInput;
        String strQueryField = '';
        List<String> fieldList = fieldAPINames.split(',');

        //check if Id is already been passed
        if(!fieldList.contains('Id')){
            fieldList.add('Id');
            strQueryField = String.join(fieldList, ',');
        }else {
            strQueryField = fieldAPINames;
        }

        String strQuery = 'SELECT ' + String.escapeSingleQuotes(strQueryField)
                        + ' FROM '
                        + String.escapeSingleQuotes(objectName)
                        + ' WHERE ' + filterFieldAPIName + '  LIKE \'' + strInput + '%\''
                        + ' ORDER BY ' + filterFieldAPIName
                        + ' LIMIT 50';

        System.debug('strQuery=' + strQuery);

        List<SObject> lstResult = database.query(strQuery);
        System.debug('--lstResult--'+lstResult);
        //create list of records that can be easily be parsable at js controller.
        for(String strField:fieldList){
            for(SObject sobj:lstResult){
                System.debug('--sobj--'+sobj);
                if(strField != 'Id'){
                    SObjectQueryResult result = new SObjectQueryResult();
                    result.recordId = (String) sobj.get('Id');
                    result.recordName = (String) sobj.get('Name');
                    lstReturnResult.add(result);
                }
            }
        }
        List<copado__User_Story__c> userStories = [
            SELECT
                Id,
                Name,
                Developer_Comments__c,
                (
                    SELECT
                        Id,
                        Name,
                        Comments__c
                    FROM
                        Review_Approvers__r
                    ORDER BY Comments__c DESC
                )
            FROM
                copado__User_Story__c
            WHERE
                Id = :userStoryId
        ];
        String reviewerComments = '';
        String developerCommments = '';
        for (copado__User_Story__c userStoryItr : userStories) {
            for (Review_Approver__c reviewItr : userStoryItr.Review_Approvers__r) {
                if (!String.isEmpty(reviewItr.Comments__c)) {
                    reviewerComments = reviewerComments + reviewItr.Comments__c;
                }
            }
            if (!String.isEmpty(userStoryItr.Developer_Comments__c)) {
                developerCommments = developerCommments + userStoryItr.Developer_Comments__c;
            }
        }
        ResultWrapper resultWrapperInstance = new ResultWrapper();
        resultWrapperInstance.sObjectQueryResults = lstReturnResult;
        resultWrapperInstance.developerComments = developerCommments;
        resultWrapperInstance.reviewerComments = reviewerComments;
        return resultWrapperInstance;
    }

    @AuraEnabled
    public static String createReviewRecords(
        List<Object> listOfSelectRecords,
        Id userStoryId,
        String devInputComments,
        String devComments
    ) {
        String responseMessage = '';
        System.debug('--listOfSelectRecords---'+listOfSelectRecords);
        System.debug('--userStoryId--'+userStoryId);
        System.debug('--devInputComments--'+devInputComments);
        System.debug('--devComments--'+devComments);
        List<Review_Approver__c> reviewApprovers = new List<Review_Approver__c>();
        //List<String> reivewNames =  new List<String>(listOfSelectRecords);
        //Map<String, String> reviewMap = new Map<String, String>(reivewNames);
        try {
            for (Object reviewerItr : listOfSelectRecords) {
                System.debug('--reviewerItr--'+reviewerItr);
                String reviewerDetails = String.valueOf(reviewerItr);
                System.debug('--reviewerDetails--'+reviewerDetails);
                List<String> reviewerRecord = reviewerDetails.split(',');
                reviewApprovers.add(new Review_Approver__c(
                    Name = reviewerRecord[0].split('=')[1],
                    Review_Status__c = 'In-Progress',
                    Reviewer__c = reviewerRecord[1].split('=')[1].removeEnd('}'),
                    User_Story__c = userStoryId
                ));
            }
            System.debug('--reviewApprovers--'+reviewApprovers);
            insert reviewApprovers;
            String devCommentsToUpdate = '';
            if (!String.isEmpty(devInputComments)) {
                devCommentsToUpdate = devInputComments + '\n' + System.now() + '\n\n';
                devCommentsToUpdate = devCommentsToUpdate + devComments;
                System.debug('--devCommentsToUpdate--'+devCommentsToUpdate);
                update new copado__User_Story__c(Id = userStoryId, Developer_Comments__c = devCommentsToUpdate);
            }
        } catch(Exception e) {
            responseMessage = e.getMessage();

        }
        return responseMessage;
    }

    public class SObjectQueryResult {
        @AuraEnabled
        public String recordId;

        @AuraEnabled
        public String recordName;

    }

    public class ResultWrapper {

        @AuraEnabled
        public List<SObjectQueryResult> sObjectQueryResults;

        @AuraEnabled
        public String developerComments;

        @AuraEnabled
        public String reviewerComments;
    }
}