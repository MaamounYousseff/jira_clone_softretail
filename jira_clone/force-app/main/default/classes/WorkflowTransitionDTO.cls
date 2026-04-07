/**
 * @description Data Transfer Object for Workflow Transition information
 */
public class WorkflowTransitionDTO {
    
    @AuraEnabled
    public String id { get; set; }
    
    @AuraEnabled
    public String name { get; set; }
    
    @AuraEnabled
    public String fromStatusId { get; set; }
    
    @AuraEnabled
    public String fromStatusName { get; set; }
    
    @AuraEnabled
    public String toStatusId { get; set; }
    
    @AuraEnabled
    public String toStatusName { get; set; }
    
    @AuraEnabled
    public String recordStatus { get; set; }
    
    @AuraEnabled
    public List<ValidationRuleDTO> validationRules { get; set; }
    
    public WorkflowTransitionDTO() {
        this.validationRules = new List<ValidationRuleDTO>();
    }
}
