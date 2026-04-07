/**
 * @description Data Transfer Object for Workflow information
 * Used to transfer workflow data between controller and LWC
 */
public class WorkflowDTO {
    
    @AuraEnabled
    public String id { get; set; }
    
    @AuraEnabled
    public String name { get; set; }
    
    @AuraEnabled
    public List<WorkflowTransitionDTO> transitions { get; set; }
    
    @AuraEnabled
    public List<StatusDTO> projectStatuses { get; set; }
    
    public WorkflowDTO() {
        this.transitions = new List<WorkflowTransitionDTO>();
        this.projectStatuses = new List<StatusDTO>();
    }
}
