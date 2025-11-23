/**
 * Created by noahr on 10/17/2024.
 */

public with sharing class ManageOppTeamMembersService {

    public static void CreateSplits(List<OpportunityTeamMember> listOfMembers, String oppId){
        List<Id> insideIds = new List<Id>();
        List<Id> outsideIds = new List<Id>();
        Id salesManagerId;
        Integer insideSize = 0;
        Integer outsideSize = 0;
        OpportunitySplit managerSplit;

        Boolean doesManagerExist = false;

        for(OpportunityTeamMember otm : listOfMembers){
            if(otm.TeamMemberRole == 'Sales Manager' && !doesManagerExist){
                salesManagerId = otm.UserId;

                managerSplit = [SELECT SplitAmount, SplitOwnerId, SplitPercentage, SplitTypeId FROM OpportunitySplit WHERE OpportunityId = :oppId AND
                SplitOwnerId = :salesManagerId];

                doesManagerExist = true;
            }

            if(otm.TeamMemberRole == 'Inside Sales Rep' || otm.TeamMemberRole == 'Opportunity Owner' || otm.TeamMemberRole == 'Sales Manager'){
                insideIds.add(otm.UserId);
                insideSize++;

            } else if (otm.TeamMemberRole == 'Outside Sales Rep'){
                outsideIds.add(otm.UserId);
                outsideSize++;
            }
        }

        try{
            List<OpportunitySplit> oppInsideSplits = [SELECT SplitAmount, SplitOwnerId, SplitPercentage, SplitTypeId FROM OpportunitySplit WHERE OpportunityId = :oppId AND
            SplitOwnerId IN :insideIds];
            Integer loopCounter = 0;
            for(OpportunitySplit is : oppInsideSplits){
                if(insideSize > 1){
                    if(doesManagerExist){
                        if(is.SplitOwnerId == salesManagerId){
                            is.SplitPercentage = 50.00;
                        }
                    }
                    if(!doesManagerExist){
                        if(insideSize == 3 && loopCounter == 2){
                            is.SplitPercentage = 33.34;
                        } else {
                            is.SplitPercentage = 100.00/insideSize;
                            loopCounter++;
                        }
                    } else if(doesManagerExist && is.SplitOwnerId != salesManagerId){
                        if(insideSize - 1 == 3){
                            if(loopCounter != 1){
                                is.SplitPercentage = 16.67;
                            } else {
                                is.SplitPercentage = 16.66;
                            }
                            loopCounter++;
                        } else {
                            is.SplitPercentage = 50.00/(insideSize - 1);
                            loopCounter++;
                        }

                    }

                } else if (insideSize == 1)  {
                    is.SplitPercentage = 100.00;
                }

                System.debug(is.SplitPercentage);
            }

            update oppInsideSplits;

        } catch(Exception e){
            System.debug(e);
        }

        try{
            List<OpportunitySplit> oppOutsideSplits = [SELECT SplitAmount, SplitOwnerId, SplitPercentage, SplitTypeId FROM OpportunitySplit WHERE OpportunityId = :oppId AND
            SplitOwnerId IN :outsideIds];

            for(OpportunitySplit os : oppOutsideSplits){
                if(outsideSize > 1){
                    os.SplitPercentage = 100.00/outsideSize;
                } else if(outsideSize == 1) {
                    os.SplitPercentage = 100.00;
                }
            }

            System.debug(oppOutsideSplits);
            update oppOutsideSplits;
        } catch(Exception e){

        }
        System.debug('Inside ' + insideIds);
        System.debug('Outside ' + outsideIds);

    }

    public static void AddNewTeamMember(String teamRole, String newUserId, String oppId){
        try{
            OpportunityTeamMember existingMember = [SELECT Id FROM OpportunityTeamMember WHERE UserId = :newUserId AND OpportunityId = :oppId];
            OpportunitySplit existingSplit = [SELECT Id FROM OpportunitySplit WHERE SplitOwnerId = :newUserId AND OpportunityId = :oppId];
            delete existingSplit;
            delete existingMember;
        } catch(Exception e){
            System.debug('New User');
        }

        List<OpportunityTeamMember> opOwnerList = new List<OpportunityTeamMember>();
        OpportunityTeamMember NewMember = new OpportunityTeamMember(
                OpportunityId = oppId,
                TeamMemberRole = teamRole,
                UserId = newUserId
        );
        if(teamRole == 'Opportunity Owner'){
            Opportunity changedOpportunity = [SELECT Id, OwnerId FROM Opportunity WHERE Id = :oppId];

            OpportunityTeamMember previousOwner = [SELECT UserId FROM OpportunityTeamMember WHERE TeamMemberRole = 'Opportunity Owner' AND OpportunityId = :oppId];
            //OpportunitySplit ownerSplits = [SELECT Id FROM OpportunitySplit WHERE SplitOwnerId = :previousOwner.Id];

            changedOpportunity.OwnerId = newUserId;
            update changedOpportunity;

            previousOwner.TeamMemberRole = 'Inside Sales Rep';
            update previousOwner;
            //delete ownerSplits;
            List<OpportunityTeamMember> membersList = [SELECT TeamMemberRole,Id,UserId FROM OpportunityTeamMember WHERE OpportunityId = :oppId];
            System.debug(membersList);
            CreateSplits(membersList,oppId);

            return;

        } else {
            //upsert NewMember;
        }
        upsert NewMember;

        String typeId = null;
        if(teamRole == 'Inside Sales Rep' || teamRole == 'Opportunity Owner' || teamRole == 'Sales Manager'){
            typeId = '149Hs000000ALHNIA4';
        } else if(teamRole == 'Outside Sales Rep'){
            typeId = '149Hs000000ALHOIA4';
        }

        if(typeId != null){
            OpportunitySplitType type = [SELECT Id FROM OpportunitySplitType WHERE Id = :typeId];
            System.debug(type);
            OpportunitySplit newSplit = new OpportunitySplit(
                    SplitOwnerId = newUserId,
                    OpportunityId = oppId,
                    SplitTypeId = type.Id
            );
            System.debug(newSplit);
            insert newSplit;
            System.debug([SELECT SplitTypeId FROM OpportunitySplit WHERE Id = :newSplit.Id]);

            List<OpportunityTeamMember> membersList = [SELECT TeamMemberRole,Id,UserId FROM OpportunityTeamMember WHERE OpportunityId = :oppId];
            System.debug(membersList);
            CreateSplits(membersList,oppId);
        }
    }

    public static void UpdateTeamMemberRole(List<String> teamRoles, List<String> memberIds, String oppId){
        List<OpportunityTeamMember> oppMem = [SELECT UserId FROM OpportunityTeamMember WHERE Id IN :memberIds AND OpportunityId = :oppId];
        List<String> userIds = new List<String>();

        for(OpportunityTeamMember opM : oppMem){
            userIds.add(opM.UserId);
        }
        try{
            List<OpportunityTeamMember> existingMember = [SELECT Id FROM OpportunityTeamMember WHERE UserId IN :userIds AND OpportunityId = :oppId];
            OpportunitySplit existingSplit = [SELECT Id FROM OpportunitySplit WHERE SplitOwnerId = :userIds AND OpportunityId = :oppId];
            delete existingSplit;
            delete existingMember;
        } catch(Exception e){
            System.debug('New User');
        }
        Integer tracker = 0;
        for(String s : teamRoles){
            AddNewTeamMember(s,oppMem[tracker].UserId ,oppId);
            tracker++;
        }

        List<OpportunityTeamMember> membersList = [SELECT TeamMemberRole,Id,UserId FROM OpportunityTeamMember WHERE OpportunityId = :oppId];
        System.debug(membersList);
        CreateSplits(membersList,oppId);
    }

    public static void DeleteTeamMember(String  memberId, String oppId){
        OpportunityTeamMember existingMember = [SELECT Id,UserId FROM OpportunityTeamMember WHERE Id = :memberId AND OpportunityId = :oppId LIMIT 1];
        List<OpportunitySplit> existingSplit = [SELECT Id FROM OpportunitySplit WHERE SplitOwnerId = :existingMember.UserId AND OpportunityId = :oppId];
        delete existingSplit;
        delete existingMember;

        List<OpportunityTeamMember> membersList = [SELECT TeamMemberRole,Id,UserId FROM OpportunityTeamMember WHERE OpportunityId = :oppId];
        System.debug(membersList);
        CreateSplits(membersList,oppId);
    }

    public static List<ManageOppTeamMembersController.testietester> GetMembers(String oppId){
        try{
            List<ManageOppTeamMembersController.testietester> testReturn = new List<ManageOppTeamMembersController.testietester>();
            List<OpportunitySplit> oppSplits = [SELECT SplitAmount, SplitOwnerId, SplitPercentage, SplitTypeId FROM OpportunitySplit WHERE OpportunityId = :oppId];
            Integer i = 1;
            for(OpportunitySplit os : oppSplits){
                ManageOppTeamMembersController.testietester memberInfo = new ManageOppTeamMembersController.testietester();
                memberInfo.SetSplitAmount(os.SplitAmount);
                memberInfo.SetSplitPercentage(os.SplitPercentage);
                User owner = [SELECT Name FROM User WHERE Id = :os.SplitOwnerId];
                memberInfo.SetName(owner.Name);
                OpportunityTeamMember mem = [SELECT TeamMemberRole FROM OpportunityTeamMember WHERE UserId = :os.SplitOwnerId AND OpportunityId = :oppId];
                memberInfo.setRole(mem.TeamMemberRole);
                memberInfo.SetStringId((mem.Id).toString());
                testReturn.add(memberInfo);
                i++;
            }
            return testReturn;
        } catch(Exception e){
            return null;
        }
    }
}