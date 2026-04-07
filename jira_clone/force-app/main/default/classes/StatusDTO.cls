/**
 * @description Data Transfer Object for Status information
 */
public class StatusDTO {
    
    @AuraEnabled
    public String id { get; set; }
    
    @AuraEnabled
    public String name { get; set; }
    
    @AuraEnabled
    public String projectId { get; set; }
}
