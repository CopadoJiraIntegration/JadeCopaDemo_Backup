public with sharing class MultiSelectLookupController {
    //This method retrieves the data from database table. It search input is '*', then retrieve all records
    @AuraEnabled (cacheable=true)
    public static List<SObjectQueryResult> retrieveRecords(String objectName, 
                                                    String fieldAPINames,
                                                    String filterFieldAPIName,
                                                    String strInput){
        
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
        return lstReturnResult;
    }

    @AuraEnabled (cacheable=true)
    public static List<SObjectQueryResult> createReviewRecords(List<Object> listOfSelectRecords) {

        System.debug('--listOfSelectRecords---'+listOfSelectRecords);
        return null;
    }
    
    public class SObjectQueryResult {
        @AuraEnabled
        public String recordId;

        @AuraEnabled
        public String recordName;
    }
}