/**
 * @description Data Transfer Object for Validation Rule information
 */
public class ValidationRuleDTO {
    
    @AuraEnabled
    public String id { get; set; }
    
    @AuraEnabled
    public String ticketField { get; set; }
    
    @AuraEnabled
    public String type { get; set; }
    
    @AuraEnabled
    public String recordStatus { get; set; }
    
    @AuraEnabled
    public String workflowTransitionId { get; set; }
}
