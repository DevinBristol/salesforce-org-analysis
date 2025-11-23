/**
 * Created by noahr on 10/17/2024.
 */

public with sharing class ManageOppTeamMembersController {
    @AuraEnabled(Cacheable=false)
    public static void AddNewTeamMemberBuffer(String teamRole, String userId, String oppId){
        ManageOppTeamMembersService.AddNewTeamMember(teamRole,userId,oppId);
    }

    @AuraEnabled(Cacheable=true)
    public static List<testietester> GetMembersBuffer(String oppId){
        return ManageOppTeamMembersService.GetMembers(oppId);
    }

    @AuraEnabled(Cacheable=false)
    public static void DeleteTeamMemberBuffer(String  memberId, String oppId){
        ManageOppTeamMembersService.DeleteTeamMember(memberId,oppId);
    }

    @AuraEnabled(Cacheable=false)
    public static void UpdateTeamMemberRoleBuffer(List<String> teamRole, List<String> memberId, String oppId){
        ManageOppTeamMembersService.UpdateTeamMemberRole(teamRole,memberId,oppId);
    }

    public class testietester{
//        @AuraEnabled
//        public Integer Id;
        @AuraEnabled
        public String Id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Double SplitAmount;
        @AuraEnabled
        public Double SplitPercentage;
        @AuraEnabled
        public String role;

        public void SetStringId(String setId){
            Id = setId;
        }
        public void SetName(String newName){
            name = newName;
        }
        public void SetSplitAmount(Decimal newAmount){
            SplitAmount = newAmount;
        }
        public void SetSplitPercentage(Decimal newPercent){
            SplitPercentage = newPercent;
        }
        public void setRole(String newRole){
            role = newRole;
        }
    }
}