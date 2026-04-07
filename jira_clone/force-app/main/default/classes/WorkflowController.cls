/**
 * @description Controller for managing Workflow configuration for Ticket Types
 * Handles workflow transitions, validation rules, and status management
 */
public with sharing class WorkflowController {
    
    /**
     * @description Get workflow with all transitions and validation rules
     * @param workflowId - The Workflow record Id
     * @return APIResponse containing WorkflowConfigDTO in data attribute
     */
    @AuraEnabled(cacheable=true)
    public static APIResponse getWorkflow(String workflowId) {
        try {
            WorkflowConfigDTO config = new WorkflowConfigDTO();
            
            // Fetch Workflow
            Workflow__c workflow = [
                SELECT Id, Name, Project__c 
                FROM Workflow__c 
                WHERE Id = :workflowId 
                LIMIT 1
            ];
            
            config.workflow.id = workflow.Id;
            config.workflow.name = workflow.Name;
            
            // Fetch all Workflow Transitions with their Validation Rules
            List<WorkflowTransition__c> transitions = [
                SELECT 
                    Id, 
                    Name, 
                    FromStatus__c, 
                    ToStatus__c, 
                    RecordStatus__c, 
                    Workflow__c,
                    (SELECT Id, TicketField__c, Type__c, RecordStatus__c 
                     FROM ValidationRules__r 
                     ORDER BY RecordStatus__c DESC, CreatedDate ASC)
                FROM WorkflowTransition__c 
                WHERE Workflow__c = :workflowId
                ORDER BY RecordStatus__c DESC, CreatedDate ASC
            ];
            
            // Build Transition infos with nested validation rules
            for (WorkflowTransition__c transition : transitions) {
                WorkflowConfigDTO.TransitionInfo transInfo = new WorkflowConfigDTO.TransitionInfo();
                transInfo.id = transition.Id;
                transInfo.name = transition.Name;
                transInfo.fromStatus = transition.FromStatus__c;
                transInfo.toStatus = transition.ToStatus__c;
                transInfo.recordStatus = transition.RecordStatus__c;
                
                // Add validation rules
                if (transition.ValidationRules__r != null) {
                    for (ValidationRule__c rule : transition.ValidationRules__r) {
                        WorkflowConfigDTO.ValidationRuleInfo ruleInfo = new WorkflowConfigDTO.ValidationRuleInfo();
                        ruleInfo.id = rule.Id;
                        ruleInfo.ticketField = rule.TicketField__c;
                        ruleInfo.type = rule.Type__c;
                        ruleInfo.recordStatus = rule.RecordStatus__c;
                        transInfo.validationRules.add(ruleInfo);
                    }
                }
                
                config.workflow.transitions.add(transInfo);
            }
            
            // Fetch Project Statuses
            if (workflow.Project__c != null) {
                List<Status__c> projectStatuses = [
                    SELECT Id, Name, Project__c
                    FROM Status__c 
                    WHERE Project__c = :workflow.Project__c
                    ORDER BY Name ASC
                ];
                
                // Build status infos
                for (Status__c status : projectStatuses) {
                    WorkflowConfigDTO.StatusInfo statusInfo = new WorkflowConfigDTO.StatusInfo();
                    statusInfo.id = status.Id;
                    statusInfo.name = status.Name;
                    config.projectStatus.add(statusInfo);
                }
            }
            
            return new APIResponse(true, 'Workflow retrieved successfully', config);
        } catch (Exception ex) {
            return new APIResponse(false, 'Error retrieving workflow: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Get all statuses for a project
     * @param projectId - The Project record Id
     * @return APIResponse containing List of Status__c objects in data attribute
     */
    @AuraEnabled(cacheable=true)
    public static APIResponse getProjectStatuses(String projectId) {
        try {
            List<Status__c> statuses = [
                SELECT Id, Name, Project__c 
                FROM Status__c 
                WHERE Project__c = :projectId
                ORDER BY Name ASC
            ];
            
            return new APIResponse(true, 'Project statuses retrieved successfully', statuses);
        } catch (Exception ex) {
            return new APIResponse(false, 'Error retrieving project statuses: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Add a new Validation Rule to a Workflow Transition
     * Precondition: Workflow Transition must exist
     * @param workflowTransitionId - The WorkflowTransition__c record Id
     * @param ticketField - The ticket field to validate
     * @param validationType - The type of validation (e.g., "not equals")
     * @return APIResponse with success status and created ValidationRule__c object
     */
    @AuraEnabled
    public static APIResponse addValidationRule(
        String workflowTransitionId, 
        String ticketField, 
        String validationType
    ) {
        try {
            // Validate inputs
            if (String.isBlank(workflowTransitionId) || String.isBlank(ticketField) || String.isBlank(validationType)) {
                return new APIResponse(false, 'Missing required parameters');
            }
            
            // Verify Workflow Transition exists
            List<WorkflowTransition__c> transitions = [
                SELECT Id FROM WorkflowTransition__c 
                WHERE Id = :workflowTransitionId 
                LIMIT 1
            ];
            
            if (transitions.isEmpty()) {
                return new APIResponse(false, 'Workflow Transition not found');
            }
            
            // Create new Validation Rule with pending status
            ValidationRule__c newRule = new ValidationRule__c();
            newRule.WorkflowTransition__c = workflowTransitionId;
            newRule.TicketField__c = ticketField;
            newRule.Type__c = validationType;
            newRule.RecordStatus__c = WorkflowConstants.RECORD_STATUS_PENDING;
            
            insert newRule;
            
            return new APIResponse(
                true, 
                'Validation Rule created successfully with pending status',
                newRule
            );
        } catch (DmlException ex) {
            return new APIResponse(false, 'DML Error: ' + ex.getMessage());
        } catch (Exception ex) {
            return new APIResponse(false, 'Error adding validation rule: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Update an existing Validation Rule
     * @param validationRuleId - The ValidationRule__c record Id
     * @param ticketField - The updated ticket field
     * @param validationType - The updated validation type
     * @return APIResponse with success status
     */
    @AuraEnabled
    public static APIResponse updateValidationRule(
        String validationRuleId, 
        String ticketField, 
        String validationType
    ) {
        try {
            // Validate inputs
            if (String.isBlank(validationRuleId) || String.isBlank(ticketField) || String.isBlank(validationType)) {
                return new APIResponse(false, 'Missing required parameters');
            }
            
            // Fetch the Validation Rule
            List<ValidationRule__c> rules = [
                SELECT Id, TicketField__c, Type__c, RecordStatus__c 
                FROM ValidationRule__c 
                WHERE Id = :validationRuleId 
                LIMIT 1
            ];
            
            if (rules.isEmpty()) {
                return new APIResponse(false, 'Validation Rule not found');
            }
            
            // Update the rule
            ValidationRule__c rule = rules[0];
            rule.TicketField__c = ticketField;
            rule.Type__c = validationType;
            
            update rule;
            
            return new APIResponse(true, 'Validation Rule updated successfully');
        } catch (DmlException ex) {
            return new APIResponse(false, 'DML Error: ' + ex.getMessage());
        } catch (Exception ex) {
            return new APIResponse(false, 'Error updating validation rule: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Delete a Validation Rule (soft delete by setting status to deleted)
     * @param validationRuleId - The ValidationRule__c record Id
     * @return APIResponse with success status
     */
    @AuraEnabled
    public static APIResponse deleteValidationRule(String validationRuleId) {
        try {
            if (String.isBlank(validationRuleId)) {
                return new APIResponse(false, 'Validation Rule Id is required');
            }
            
            List<ValidationRule__c> rules = [
                SELECT Id, RecordStatus__c 
                FROM ValidationRule__c 
                WHERE Id = :validationRuleId 
                LIMIT 1
            ];
            
            if (rules.isEmpty()) {
                return new APIResponse(false, 'Validation Rule not found');
            }
            
            // Soft delete: set status to deleted
            ValidationRule__c rule = rules[0];
            rule.RecordStatus__c = WorkflowConstants.RECORD_STATUS_DELETED;
            
            update rule;
            
            return new APIResponse(true, 'Validation Rule deleted successfully');
        } catch (DmlException ex) {
            return new APIResponse(false, 'DML Error: ' + ex.getMessage());
        } catch (Exception ex) {
            return new APIResponse(false, 'Error deleting validation rule: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Add a new Workflow Transition to an existing Workflow
     * @param workflowId - The Workflow__c record Id
     * @param name - The name of the transition
     * @param fromStatusId - The Id of the from status
     * @param toStatusId - The Id of the to status
     * @return APIResponse with success status and created WorkflowTransition__c object
     */
    @AuraEnabled
    public static APIResponse addWorkflowTransition(
        String workflowId, 
        String name, 
        String fromStatusId, 
        String toStatusId
    ) {
        try {
            // Validate inputs
            if (String.isBlank(workflowId) || String.isBlank(name) || 
                String.isBlank(fromStatusId) || String.isBlank(toStatusId)) {
                return new APIResponse(false, 'Missing required parameters');
            }
            
            // Verify Workflow exists
            List<Workflow__c> workflows = [
                SELECT Id FROM Workflow__c 
                WHERE Id = :workflowId 
                LIMIT 1
            ];
            
            if (workflows.isEmpty()) {
                return new APIResponse(false, 'Workflow not found');
            }
            
            // Verify both statuses exist
            List<Status__c> statuses = [
                SELECT Id FROM Status__c 
                WHERE Id IN (:fromStatusId, :toStatusId)
            ];
            
            if (statuses.size() != 2) {
                return new APIResponse(false, 'One or both statuses not found');
            }
            
            // Create new Workflow Transition with pending status
            WorkflowTransition__c newTransition = new WorkflowTransition__c();
            newTransition.Workflow__c = workflowId;
            newTransition.Name = name;
            newTransition.FromStatus__c = fromStatusId;
            newTransition.ToStatus__c = toStatusId;
            newTransition.RecordStatus__c = WorkflowConstants.RECORD_STATUS_PENDING;
            
            insert newTransition;
            
            return new APIResponse(
                true, 
                'Workflow Transition created successfully with pending status',
                newTransition
            );
        } catch (DmlException ex) {
            return new APIResponse(false, 'DML Error: ' + ex.getMessage());
        } catch (Exception ex) {
            return new APIResponse(false, 'Error adding workflow transition: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Activate a Validation Rule (change status from pending to active)
     * One-way operation: can only go from pending to active, not the reverse
     * @param validationRuleId - The ValidationRule__c record Id
     * @return APIResponse with success status
     */
    @AuraEnabled
    public static APIResponse activateValidationRule(String validationRuleId) {
        try {
            if (String.isBlank(validationRuleId)) {
                return new APIResponse(false, 'Validation Rule Id is required');
            }
            
            List<ValidationRule__c> rules = [
                SELECT Id, RecordStatus__c 
                FROM ValidationRule__c 
                WHERE Id = :validationRuleId 
                LIMIT 1
            ];
            
            if (rules.isEmpty()) {
                return new APIResponse(false, 'Validation Rule not found');
            }
            
            ValidationRule__c rule = rules[0];
            
            // Can only activate if currently pending
            if (rule.RecordStatus__c != WorkflowConstants.RECORD_STATUS_PENDING) {
                return new APIResponse(
                    false, 
                    'Validation Rule can only be activated from pending status'
                );
            }
            
            rule.RecordStatus__c = WorkflowConstants.RECORD_STATUS_ACTIVE;
            update rule;
            
            return new APIResponse(true, 'Validation Rule activated successfully');
        } catch (DmlException ex) {
            return new APIResponse(false, 'DML Error: ' + ex.getMessage());
        } catch (Exception ex) {
            return new APIResponse(false, 'Error activating validation rule: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Activate a Workflow Transition (change status from pending to active)
     * @param workflowTransitionId - The WorkflowTransition__c record Id
     * @return APIResponse with success status
     */
    @AuraEnabled
    public static APIResponse activateWorkflowTransition(String workflowTransitionId) {
        try {
            if (String.isBlank(workflowTransitionId)) {
                return new APIResponse(false, 'Workflow Transition Id is required');
            }
            
            List<WorkflowTransition__c> transitions = [
                SELECT Id, RecordStatus__c 
                FROM WorkflowTransition__c 
                WHERE Id = :workflowTransitionId 
                LIMIT 1
            ];
            
            if (transitions.isEmpty()) {
                return new APIResponse(false, 'Workflow Transition not found');
            }
            
            WorkflowTransition__c transition = transitions[0];
            
            // Can only activate if currently pending
            if (transition.RecordStatus__c != WorkflowConstants.RECORD_STATUS_PENDING) {
                return new APIResponse(
                    false, 
                    'Workflow Transition can only be activated from pending status'
                );
            }
            
            transition.RecordStatus__c = WorkflowConstants.RECORD_STATUS_ACTIVE;
            update transition;
            
            return new APIResponse(true, 'Workflow Transition activated successfully');
        } catch (DmlException ex) {
            return new APIResponse(false, 'DML Error: ' + ex.getMessage());
        } catch (Exception ex) {
            return new APIResponse(false, 'Error activating workflow transition: ' + ex.getMessage());
        }
    }
    
    /**
     * @description Final update workflow: activate all pending transitions and validation rules
     * This is called when the user clicks the Update Workflow button
     * Precondition: At least one new transition or validation rule must have been added
     * @param workflowId - The Workflow__c record Id
     * @return APIResponse with success status
     */
    @AuraEnabled
    public static APIResponse updateWorkflow(String workflowId) {
        try {
            if (String.isBlank(workflowId)) {
                return new APIResponse(false, 'Workflow Id is required');
            }
            
            // Verify Workflow exists
            List<Workflow__c> workflows = [
                SELECT Id FROM Workflow__c 
                WHERE Id = :workflowId 
                LIMIT 1
            ];
            
            if (workflows.isEmpty()) {
                return new APIResponse(false, 'Workflow not found');
            }
            
            // Get all pending transitions and validation rules for this workflow
            List<WorkflowTransition__c> pendingTransitions = [
                SELECT Id, RecordStatus__c 
                FROM WorkflowTransition__c 
                WHERE Workflow__c = :workflowId 
                  AND RecordStatus__c = :WorkflowConstants.RECORD_STATUS_PENDING
            ];
            
            List<ValidationRule__c> pendingRules = [
                SELECT Id, RecordStatus__c 
                FROM ValidationRule__c 
                WHERE WorkflowTransition__c IN (
                    SELECT Id FROM WorkflowTransition__c WHERE Workflow__c = :workflowId
                )
                  AND RecordStatus__c = :WorkflowConstants.RECORD_STATUS_PENDING
            ];
            
            // Activate all pending transitions
            for (WorkflowTransition__c transition : pendingTransitions) {
                transition.RecordStatus__c = WorkflowConstants.RECORD_STATUS_ACTIVE;
            }
            
            // Activate all pending validation rules
            for (ValidationRule__c rule : pendingRules) {
                rule.RecordStatus__c = WorkflowConstants.RECORD_STATUS_ACTIVE;
            }
            
            // Perform bulk update
            List<SObject> recordsToUpdate = new List<SObject>();
            recordsToUpdate.addAll(pendingTransitions);
            recordsToUpdate.addAll(pendingRules);
            
            if (!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
            }
            
            return new APIResponse(
                true, 
                'Workflow updated successfully. All pending transitions and validation rules activated.'
            );
        } catch (DmlException ex) {
            return new APIResponse(false, 'DML Error: ' + ex.getMessage());
        } catch (Exception ex) {
            return new APIResponse(false, 'Error updating workflow: ' + ex.getMessage());
        }
    }
}
