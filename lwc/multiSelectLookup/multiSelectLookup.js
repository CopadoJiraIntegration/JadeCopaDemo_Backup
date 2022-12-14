/*
 *   Author: Santanu Boral
*/
import { LightningElement, api, track } from 'lwc';
import createReviewRecords from '@salesforce/apex/MultiSelectLookupController.createReviewRecords';
import retrieveRecords from '@salesforce/apex/MultiSelectLookupController.retrieveRecords';
import initialRecords from '@salesforce/apex/MultiSelectLookupController.initialRecords';
import SystemModstamp from '@salesforce/schema/Account.SystemModstamp';

let i=0;
export default class multiSelectLookup extends LightningElement {

    @track globalSelectedItems = []; //holds all the selected checkbox items
    //start: following parameters to be passed from calling component
    @api labelName;
    @api recordId;  // User Story Id
    @api objectApiName; // = 'Contact';
    @api fieldApiNames; // = 'Id,Name';
    @api filterFieldApiName;    // = 'Name';
    @api iconName;  // = 'standard:contact';
    //end---->
    @track items = []; //holds all records retrieving from database
    @track selectedItems = []; //holds only selected checkbox items that is being displayed based on search

    //since values on checkbox deselection is difficult to track, so workaround to store previous values.
    //clicking on Done button, first previousSelectedItems items to be deleted and then selectedItems to be added into globalSelectedItems
    @track previousSelectedItems = []; 
    @track existingItems = [];
    @track value = []; //this holds checkbox values (Ids) which will be shown as selected
    searchInput ='';    //captures the text to be searched from user input
    isDialogDisplay = false; //based on this flag dialog box will be displayed with checkbox items
    isDisplayMessage = false; //to show 'No records found' message
    isSuccess = false;
    isDisabled = true;
    errorMessage = '';
    devCommentInput = '';
    devComments = '';
    approverComments = '';
    isCompleted = false;
    

    connectedCallback() {
        initialRecords()
        initialRecords({
            userstoryId: this.recordId
        })
        .then(result=>{ 
        console.log('-result--',result);
        this.devComments = result.developerComments;
        this.approverComments = result.reviewerComments;
        if(result.sObjectQueryResults.length>0){
            result.sObjectQueryResults.map(resElement=>{
                this.existingItems.push({value:resElement.recordId, 
                    label:resElement.recordName});
            });
            this.isDialogDisplay = true; //display dialog
            this.isDisplayMessage = false;
            this.isDisabled = false;
        }
        else{
            //display No records found message
            this.isDialogDisplay = false;
            this.isDisplayMessage = true;                    
        }
        })
        .catch(error=>{
            this.error = error;
            this.items = undefined;
            this.isDialogDisplay = false;
        })
    }

    handleDevCommentsChange(event) {
        this.devCommentInput = event.detail.value;
    }

    //This method is called when user enters search input. It displays the data from database.
    onchangeSearchInput(event){

        this.searchInput = event.target.value;
        if(this.searchInput.trim().length>0){
            //retrieve records based on search input
            retrieveRecords({objectName: this.objectApiName,
                            fieldAPINames: this.fieldApiNames,
                            filterFieldAPIName: this.filterFieldApiName,
                            strInput: this.searchInput,
                            userStoryId: this.recordId
                            })
            .then(result=>{ 
                this.items = []; //initialize the array before assigning values coming from apex
                this.value = [];
                this.previousSelectedItems = [];
                console.log('-result--',result);
                this.devComments = result.developerComments;
                this.approverComments = result.reviewerComments;
                if(result.sObjectQueryResults.length>0){
                    result.sObjectQueryResults.map(resElement=>{
                        //prepare items array using spread operator which will be used as checkbox options
                        this.items = [...this.items,{value:resElement.recordId, 
                                                    label:resElement.recordName}];
                        
                        /*since previously choosen items to be retained, so create value array for checkbox group.
                            This value will be directly assigned as checkbox value & will be displayed as checked.
                        */
                        this.globalSelectedItems.map(element =>{
                            if(element.value == resElement.recordId){
                                this.value.push(element.value);
                                this.previousSelectedItems.push(element);                      
                            }
                        });
                    });
                    this.isDialogDisplay = true; //display dialog
                    this.isDisplayMessage = false;
                }
                else{
                    //display No records found message
                    this.isDialogDisplay = false;
                    this.isDisplayMessage = true;                    
                }
            })
            .catch(error=>{
                this.error = error;
                this.items = undefined;
                this.isDialogDisplay = false;
            })
        }else{
            this.isDialogDisplay = false;
        }                
    }

    //This method is called during checkbox value change
    handleCheckboxChange(event){
        let selectItemTemp = event.detail.value;
        
        //all the chosen checkbox items will come as follows: selectItemTemp=0032v00002x7UE9AAM,0032v00002x7UEHAA2
        console.log(' handleCheckboxChange  value=', event.detail.value);        
        this.selectedItems = []; //it will hold only newly selected checkbox items.        
        
        /* find the value in items array which has been prepared during database call
           and push the key/value inside selectedItems array           
        */
        selectItemTemp.map(p=>{            
            let arr = this.items.find(element => element.value == p);
            //arr = value: "0032v00002x7UEHAA2", label: "Arthur Song
            if(arr != undefined){
                this.selectedItems.push(arr);
            }  
        });   
        this.isDisabled = false;  
    }

    //this method removes the pill item
    handleRemoveRecord(event){        
        const removeItem = event.target.dataset.item; //"0032v00002x7UEHAA2"
        
        //this will prepare globalSelectedItems array excluding the item to be removed.
        this.globalSelectedItems = this.globalSelectedItems.filter(item => item.value  != removeItem);
        const arrItems = this.globalSelectedItems;

        //initialize values again
        this.initializeValues();
        this.value =[]; 

        //propagate event to parent component
        const evtCustomEvent = new CustomEvent('remove', {   
            detail: {removeItem,arrItems}
            });
        this.dispatchEvent(evtCustomEvent);
    }

    //Done dialog button click event prepares globalSelectedItems which is used to display pills
    handleSelectClick(event){
        //remove previous selected items first as there could be changes in checkbox selection
        this.previousSelectedItems.map(p=>{
            this.globalSelectedItems = this.globalSelectedItems.filter(item => item.value != p.value);
        });
        
        //now add newly selected items to the globalSelectedItems
        this.globalSelectedItems.push(...this.selectedItems);        
        const arrItems = this.globalSelectedItems;
        
        //store current selection as previousSelectionItems
        this.previousSelectedItems = this.selectedItems;
        this.initializeValues();
        
        //propagate event to parent component
        const evtCustomEvent = new CustomEvent('retrieve', { 
            detail: {arrItems}
            });
        this.dispatchEvent(evtCustomEvent);
    }

    handleDoneClick(event) {

        console.log('-Inside the handleDoneClick--');
        createReviewRecords({
            listOfSelectRecords: this.globalSelectedItems,
            listOfExistingReviewers : this.existingItems,
            userStoryId : this.recordId,
            devInputComments : this.devCommentInput,
            devComments : this.devComments
        })
        .then(result=>{ 
            console.log('--result--',result);
            if (result == '') {
                this.isSuccess = true;
            }
            else {
                this.errorMessage = result;
            }
            console.log('--Records saved--',result);
        })
        .catch(error=>{
            this.errorMessage = error;
            this.items = undefined;
            this.isDialogDisplay = false;
        })
        this.isDisabled = true;

    }

    //Cancel button click hides the dialog
    handleCancelClick(event){
        this.initializeValues();
    }

    //this method initializes values after performing operations
    initializeValues(){
        this.searchInput = '';        
        this.isDialogDisplay = false;
    }
}