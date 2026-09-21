public with sharing class AccountTriggerHandler {

    public static final String HANDLER_NAME = 'AccountTriggerHandler_v2';

    public enum TestStatus {
        CREATED,
        ERROR
    }

    public class Result {
        public Integer createdTests;
        public Boolean hasErrors;
    }

    public static Result beforeInsert(List<Account> newAccounts) {

        Result r = new Result();
        r.createdTests = 0;
        r.hasErrors = false;

        // Зависимость на класс git
        git.touch();

        // Зависимость от кастомного объекта: поведение триггера настраивается
        // через Account_Trigger_Setting__c, чтобы админы могли включать/выключать
        // автоматизацию или менять префикс имени без правки Apex.
        Account_Trigger_Setting__c settings = getTriggerSettings();

        if (settings != null && settings.Is_Active__c == false) {
            return r;
        }

        // Ещё одна зависимость: автоматизация работает только для пользователей,
        // которым назначена группа прав testPG.
        if (!hasPermissionSetGroup('testPG')) {
            return r;
        }

        String namePrefix = (settings != null && String.isNotBlank(settings.Test_Name_Prefix__c))
            ? settings.Test_Name_Prefix__c
            : 'Auto for ';

        List<Test__c> testsToInsert = new List<Test__c>();

        for (Account acc : newAccounts) {
            if (String.isBlank(acc.Name)) {
                acc.addError('Account Name is required');
                r.hasErrors = true;
                continue;
            }

            Test__c t = new Test__c(
                Name = namePrefix + acc.Name
            );

            testsToInsert.add(t);
        }

        if (!testsToInsert.isEmpty()) {
            insert testsToInsert;
            r.createdTests = testsToInsert.size();
        }

        return r;
    }

    private static Account_Trigger_Setting__c getTriggerSettings() {
        List<Account_Trigger_Setting__c> settings = [
            SELECT Is_Active__c, Test_Name_Prefix__c
            FROM Account_Trigger_Setting__c
            LIMIT 1
        ];
        return settings.isEmpty() ? null : settings[0];
    }

    private static Boolean hasPermissionSetGroup(String developerName) {
        List<PermissionSetGroup> groups = [
            SELECT Id
            FROM PermissionSetGroup
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];

        if (groups.isEmpty()) {
            return false;
        }

        List<PermissionSetAssignment> assignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSet.PermissionSetGroupId = :groups[0].Id
            LIMIT 1
        ];

        return !assignments.isEmpty();
    }
}