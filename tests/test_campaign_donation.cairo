use core::array::ArrayTrait;
use core::traits::Into;
use fundable::base::types::{Campaigns, DonationMetadata, Donations};
use fundable::campaign_donation::CampaignDonation;
use fundable::interfaces::ICampaignDonation::{
    ICampaignDonationDispatcher, ICampaignDonationDispatcherTrait,
};
use fundable::interfaces::IDonationNFT::{IDonationNFTDispatcher, IDonationNFTDispatcherTrait};
use openzeppelin::access::accesscontrol::interface::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::token::erc721::interface::{
    IERC721Dispatcher, IERC721DispatcherTrait, IERC721MetadataDispatcher,
    IERC721MetadataDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpy, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address, test_address,
};
use starknet::{ContractAddress, contract_address_const};

fn setup() -> (ContractAddress, ContractAddress, ICampaignDonationDispatcher, IERC721Dispatcher) {
    let sender: ContractAddress = contract_address_const::<'sender'>();
    // Deploy mock ERC20
    let erc20_class = declare("MockUsdc").unwrap().contract_class();
    let mut calldata = array![sender.into(), sender.into(), 6];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();

    // Deploy Campaign Donation contract
    let protocol_owner: ContractAddress = contract_address_const::<'protocol_owner'>();
    let campaign_donation_class = declare("CampaignDonation").unwrap().contract_class();
    let mut calldata = array![protocol_owner.into(), erc20_address.into()];
    let (campaign_donation_address, _) = campaign_donation_class.deploy(@calldata).unwrap();

    (
        erc20_address,
        sender,
        ICampaignDonationDispatcher { contract_address: campaign_donation_address },
        IERC721Dispatcher { contract_address: campaign_donation_address },
    )
}

fn deploy_donation_nft(
    campaign_donation_address: ContractAddress,
) -> (IERC721Dispatcher, IDonationNFTDispatcher) {
    let donation_nft_class = declare("DonationNFT").unwrap().contract_class();
    let mut calldata = array![campaign_donation_address.into()];
    let (donation_nft_address, _) = donation_nft_class.deploy(@calldata).unwrap();
    let ierc721_dispatcher = IERC721Dispatcher { contract_address: donation_nft_address };
    let idonation_nft_dispatcher = IDonationNFTDispatcher {
        contract_address: donation_nft_address,
    };
    (ierc721_dispatcher, idonation_nft_dispatcher)
}

// DONE

#[test]
fn test_successful_create_campaign() {
    let (_token_address, _sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;
    let campaign_ref = 'Test';
    let owner = contract_address_const::<'owner'>();

    start_cheat_caller_address(campaign_donation.contract_address, owner);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);
    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    let campaign = campaign_donation.get_campaign(campaign_id);
    assert(campaign.campaign_id == campaign_id, 'Campaign ID mismatch');
    assert(campaign.owner == owner, 'Owner mismatch');
    assert(campaign.target_amount == target_amount, 'Target amount mismatch');
    assert(campaign.current_balance == 0.into(), 'Current amount should be 0');
    assert(campaign.campaign_reference == campaign_ref, 'Reference mismatch');
    assert(!campaign.is_closed, 'Campaign should not be closed');
    assert(!campaign.is_goal_reached, 'Goal should not be reached');
}

// DONE
#[test]
#[should_panic(expected: 'Error: Amount must be > 0.')]
fn test_create_campaign_invalid_zero_amount() {
    let (_token_address, _sender, campaign_donation, _erc721) = setup();
    let target_amount = 0_u256;
    let campaign_ref = 'Test';
    let owner = contract_address_const::<'owner'>();
    start_cheat_caller_address(campaign_donation.contract_address, owner);
    campaign_donation.create_campaign(campaign_ref, target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

// #[test]
// #[should_panic(expected: 'Error: Campaign Ref Exists')]
// fn test_create_campaign_duplicate_campaign_refs() {
//     let (_token_address, _sender, campaign_donation, _erc721) = setup();
//     let target_amount = 50_u256;
//     let asset = 'Test';
//     let campaign_ref = 'Test';
//     let owner = contract_address_const::<'owner'>();
//     start_cheat_caller_address(campaign_donation.contract_address, owner);
//     campaign_donation.create_campaign(campaign_ref, target_amount);
//     campaign_donation.create_campaign(campaign_ref, target_amount);
//     stop_cheat_caller_address(campaign_donation.contract_address);
// }

// #[test]
// #[should_panic(expected: 'Error: Campaign Ref Is Required')]
// fn test_create_campaign_empty_campaign_refs() {
//     let (_token_address, _sender, campaign_donation, _erc721) = setup();
//     let target_amount = 100_u256;
//     let asset = 'Test';
//     let campaign_ref = '';
//     let owner = contract_address_const::<'owner'>();
//     start_cheat_caller_address(campaign_donation.contract_address, owner);
//     campaign_donation.create_campaign(campaign_ref, target_amount);
//     stop_cheat_caller_address(campaign_donation.contract_address);
// }

// DONE
#[test]
fn test_successful_campaign_donation() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 5000_u256;
    let campaign_ref = 'Test';

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    stop_cheat_caller_address(campaign_donation.contract_address);

    let user_balance_before = token_dispatcher.balance_of(sender);
    println!("user balance before: {}", user_balance_before);
    let contract_balance_before = token_dispatcher.balance_of(campaign_donation.contract_address);
    println!("contract balance before: {}", contract_balance_before);

    // Simulate delegate's approval:
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(token_address);

    let allowance = token_dispatcher.allowance(sender, campaign_donation.contract_address);
    assert(allowance >= 1000, 'Allowance not set correctly');
    println!("Allowance for withdrawal: {}", allowance);

    start_cheat_caller_address(campaign_donation.contract_address, sender);

    let donation_id = campaign_donation.donate_to_campaign(campaign_id, 500);

    stop_cheat_caller_address(campaign_donation.contract_address);

    let donation = campaign_donation.get_donation(campaign_id, donation_id);
    assert(donation.donation_id == 1, ' not initalized Properly');
    assert(donation.donor == sender, 'sender failed');
    assert(donation.campaign_id == campaign_id, 'campaing id failed');
    assert(donation.amount == 500, 'fund not eflecting');

    let user_balance_after = token_dispatcher.balance_of(sender);
    println!("user balance after: {}", user_balance_after);
    let contract_balance_after = token_dispatcher.balance_of(campaign_donation.contract_address);
    println!("contract balance after: {}", contract_balance_after);

    assert(
        (contract_balance_before == 0) && (contract_balance_after == 500), 'CON transfer failed',
    );
    assert(user_balance_after == user_balance_before - 500, ' USR transfer failed');
}

// DONE
#[test]
fn test_successful_campaign_donation_twice() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;
    let campaign_ref = 'Test';

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    stop_cheat_caller_address(campaign_donation.contract_address);

    let user_balance_before = token_dispatcher.balance_of(sender);
    let contract_balance_before = token_dispatcher.balance_of(campaign_donation.contract_address);

    // Simulate delegate's approval:
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(campaign_donation.contract_address, sender);

    let _donation_id = campaign_donation.donate_to_campaign(campaign_id, 500);
    let donation_id_1 = campaign_donation.donate_to_campaign(campaign_id, 300);

    stop_cheat_caller_address(campaign_donation.contract_address);

    let donation = campaign_donation.get_donation(campaign_id, donation_id_1);

    assert(donation.donation_id == 2, ' not initalized Properly');
    assert(donation.amount == 300, 'fund not eflecting');

    let user_balance_after = token_dispatcher.balance_of(sender);
    let contract_balance_after = token_dispatcher.balance_of(campaign_donation.contract_address);
    assert((contract_balance_before == 0) && (contract_balance_after == 800), 'transfer failed');
    assert(user_balance_after == user_balance_before - 800, ' USR transfer failed');
}


#[test]
fn test_successful_multiple_users_donating_to_a_campaign() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 10000_u256;
    let campaign_ref = 'Test';
    let another_user: ContractAddress = contract_address_const::<'another_user'>();

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    stop_cheat_caller_address(campaign_donation.contract_address);

    let contract_balance_before = token_dispatcher.balance_of(campaign_donation.contract_address);

    println!("contract balance before: {}", contract_balance_before);
    // Simulate delegate's approval:
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 100000);
    token_dispatcher.transfer(another_user, 10000);
    let other_user_balance_before = token_dispatcher.balance_of(another_user);
    println!("other user balance before: {}", other_user_balance_before);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_address, another_user);
    token_dispatcher.approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let _donation_id = campaign_donation.donate_to_campaign(campaign_id, 500);
    stop_cheat_caller_address(campaign_donation.contract_address);

    start_cheat_caller_address(campaign_donation.contract_address, another_user);
    let donation_id_1 = campaign_donation.donate_to_campaign(campaign_id, 300);
    stop_cheat_caller_address(campaign_donation.contract_address);

    let donation = campaign_donation.get_donation(campaign_id, donation_id_1);

    assert(donation.donation_id == 2, ' not initalized Properly');
    assert(donation.amount == 300, 'fund not eflecting');

    let other_user_balance_after = token_dispatcher.balance_of(another_user);
    let contract_balance_after = token_dispatcher.balance_of(campaign_donation.contract_address);
    println!("contract balance after: {}", contract_balance_after);
    assert((contract_balance_before == 0) && (contract_balance_after == 800), 'transfer failed');
    assert(other_user_balance_after == other_user_balance_before - 300, ' USR transfer failed');
}

#[test]
fn test_target_met_successful() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;
    let campaign_ref = 'Test';

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    stop_cheat_caller_address(campaign_donation.contract_address);

    // Simulate delegate's approval:
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 10000);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(campaign_donation.contract_address, sender);

    let _donation_id = campaign_donation.donate_to_campaign(campaign_id, 1000);

    stop_cheat_caller_address(campaign_donation.contract_address);

    let campaign = campaign_donation.get_campaign(campaign_id);

    assert(campaign.is_goal_reached, 'target error');
    assert(campaign.is_closed, 'target error');
}

#[test]
fn test_get_campaigns() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount_1 = 1000_u256;
    let target_amount_2 = 2000_u256;
    let target_amount_3 = 3000_u256;

    // Create multiple campaigns with different references
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id_1 = campaign_donation.create_campaign('Ref1', target_amount_1);
    let campaign_id_2 = campaign_donation.create_campaign('Ref2', target_amount_2);
    let campaign_id_3 = campaign_donation.create_campaign('Ref3', target_amount_3);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Get all campaigns
    let campaigns = campaign_donation.get_campaigns();

    // Verify campaign count
    assert(campaigns.len() == 3, 'Should return 3 campaigns');

    // Verify campaign details
    let campaign_1 = campaigns.at(0);
    let campaign_2 = campaigns.at(1);
    let campaign_3 = campaigns.at(2);

    // Verify first campaign
    assert(*campaign_1.campaign_id == campaign_id_1, 'Campaign 1 ID mismatch');
    assert(*campaign_1.owner == sender, 'Campaign 1 owner mismatch');
    assert(*campaign_1.target_amount == target_amount_1, 'Campaign 1 target mismatch');
    assert(*campaign_1.campaign_reference == 'Ref1', 'Campaign 1 ref mismatch');

    // Verify second campaign
    assert(*campaign_2.campaign_id == campaign_id_2, 'Campaign 2 ID mismatch');
    assert(*campaign_2.target_amount == target_amount_2, 'Campaign 2 target mismatch');
    assert(*campaign_2.campaign_reference == 'Ref2', 'Campaign 2 ref mismatch');

    // Verify third campaign
    assert(*campaign_3.campaign_id == campaign_id_3, 'Campaign 3 ID mismatch');
    assert(*campaign_3.target_amount == target_amount_3, 'Campaign 3 target mismatch');
    assert(*campaign_3.campaign_reference == 'Ref3', 'Campaign 3 ref mismatch');
}

#[test]
fn test_get_campaign_donations() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let another_user: ContractAddress = contract_address_const::<'another_user'>();
    let target_amount = 5000_u256;

    // Create a campaign
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('TestCampaign', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // Setup token approvals for both users
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 10000);
    token_dispatcher.transfer(another_user, 10000);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_address, another_user);
    token_dispatcher.approve(campaign_donation.contract_address, 10000);
    stop_cheat_caller_address(token_address);

    // Make multiple donations from different users
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let donation_id_1 = campaign_donation.donate_to_campaign(campaign_id, 500);
    let donation_id_2 = campaign_donation.donate_to_campaign(campaign_id, 700);
    stop_cheat_caller_address(campaign_donation.contract_address);

    start_cheat_caller_address(campaign_donation.contract_address, another_user);
    let donation_id_3 = campaign_donation.donate_to_campaign(campaign_id, 300);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Get all donations for the campaign
    let donations = campaign_donation.get_campaign_donations(campaign_id);

    // Verify donation count
    assert(donations.len() == 3, 'Should return 3 donations');

    // Verify donation details
    let donation_1 = donations.at(0);
    let donation_2 = donations.at(1);
    let donation_3 = donations.at(2);

    // Verify first donation
    assert(*donation_1.donation_id == donation_id_1, 'Donation 1 ID mismatch');
    assert(*donation_1.donor == sender, 'Donation 1 donor mismatch');
    assert(*donation_1.amount == 500, 'Donation 1 amount mismatch');

    // Verify second donation
    assert(*donation_2.donation_id == donation_id_2, 'Donation 2 ID mismatch');
    assert(*donation_2.donor == sender, 'Donation 2 donor mismatch');
    assert(*donation_2.amount == 700, 'Donation 2 amount mismatch');

    // Verify third donation
    assert(*donation_3.donation_id == donation_id_3, 'Donation 3 ID mismatch');
    assert(*donation_3.donor == another_user, 'Donation 3 donor mismatch');
    assert(*donation_3.amount == 300, 'Donation 3 amount mismatch');

    // Verify campaign data is updated correctly
    let campaign = campaign_donation.get_campaign(campaign_id);
    assert(campaign.current_balance == 1500, 'Campaign amount mismatch');
}

#[test]
fn test_get_campaign_donations_empty() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;

    // Create a campaign but don't make any donations
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('EmptyCampaign', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Get donations for the campaign
    let donations = campaign_donation.get_campaign_donations(campaign_id);

    // Verify no donations are returned
    assert(donations.len() == 0, 'Should return empty array');
}

#[test]
fn test_multiple_campaigns_with_donations() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;

    // Create multiple campaigns
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id_1 = campaign_donation.create_campaign('Campaign1', target_amount);
    let campaign_id_2 = campaign_donation.create_campaign('Campaign2', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

    // Setup token approvals
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 10000);
    stop_cheat_caller_address(token_address);

    // Make donations to both campaigns
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let _donation_id_1 = campaign_donation.donate_to_campaign(campaign_id_1, 100);
    let _donation_id_2 = campaign_donation.donate_to_campaign(campaign_id_1, 200);
    let _donation_id_3 = campaign_donation.donate_to_campaign(campaign_id_2, 300);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Get donations for campaign 1
    let donations_1 = campaign_donation.get_campaign_donations(campaign_id_1);
    assert(donations_1.len() == 2, 'wrong donation count 1');
    assert(*donations_1.at(0).amount == 100, '1st donation amt error');
    assert(*donations_1.at(1).amount == 200, '2nd donation amt error');

    // Get donations for campaign 2
    let donations_2 = campaign_donation.get_campaign_donations(campaign_id_2);
    assert(donations_2.len() == 1, 'wrong donation count 2');
    assert(*donations_2.at(0).amount == 300, '3rd donation amount error');

    // Verify get_campaigns returns both campaigns
    let campaigns = campaign_donation.get_campaigns();
    assert(campaigns.len() == 2, 'Should return 2 campaigns');
}

#[test]
#[fork(url: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8", block_tag: latest)]
fn test_withdraw_funds_from_campaign_successful() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 800_u256;
    let campaign_ref = 'Test';
    let owner = contract_address_const::<'owner'>();

    start_cheat_caller_address(campaign_donation.contract_address, owner);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    stop_cheat_caller_address(campaign_donation.contract_address);
    // This is the first Campaign Created, so it will be 1.
    assert!(campaign_id == 1_u256, "Campaign creation failed");

    // let donor = contract_address_const::<'donor'>();

    let user_balance_before = token_dispatcher.balance_of(sender);
    println!("user balance before: {}", user_balance_before);
    let contract_balance_before = token_dispatcher.balance_of(campaign_donation.contract_address);
    println!("contract balance before: {}", contract_balance_before);

    // Simulate delegate's approval:
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(token_address);

    let allowance = token_dispatcher.allowance(sender, campaign_donation.contract_address);
    println!("Allowance for withdrawal: {}", allowance);

    assert(allowance >= 1000, 'Allowance not set correctly');

    start_cheat_caller_address(campaign_donation.contract_address, sender);

    let donation_id = campaign_donation.donate_to_campaign(campaign_id, 800);

    stop_cheat_caller_address(campaign_donation.contract_address);

    // let donation = campaign_donation.get_donation(campaign_id, donation_id);

    start_cheat_caller_address(campaign_donation.contract_address, owner);

    let owner_balance_before = token_dispatcher.balance_of(owner);
    println!("campaign owner balance before: {}", owner_balance_before);
    let contract_balance_before = token_dispatcher.balance_of(campaign_donation.contract_address);
    println!("contract  balance before: {}", contract_balance_before);
    campaign_donation.withdraw_from_campaign(campaign_id);

    let owner_balance_after = token_dispatcher.balance_of(owner);
    println!("campaign owner balance after: {}", owner_balance_after);
    let contract_balance_after = token_dispatcher.balance_of(campaign_donation.contract_address);

    println!("contract balance after: {}", contract_balance_after);
    stop_cheat_caller_address(campaign_donation.contract_address);

    assert(owner_balance_after - owner_balance_before == 800, 'Withdrawal error')
}

#[test]
fn test_update_campaign_target_successful() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;
    let new_target = 2000_u256;

    // Create campaign
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('Test', target_amount);

    // Update target
    campaign_donation.update_campaign_target(campaign_id, new_target);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Verify update
    let campaign = campaign_donation.get_campaign(campaign_id);
    assert(campaign.target_amount == new_target, 'Target not updated');
}

#[test]
#[should_panic(expected: 'Error: Campaign Not Found')]
fn test_update_campaign_target_nonexistent() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    campaign_donation.update_campaign_target(999, 2000);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

#[test]
#[should_panic(expected: 'Caller is Not Campaign Owner')]
fn test_update_campaign_target_not_owner() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();
    let other_user: ContractAddress = contract_address_const::<'other_user'>();

    // Create campaign as sender
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('Test', 1000);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Try to update as other user
    start_cheat_caller_address(campaign_donation.contract_address, other_user);
    campaign_donation.update_campaign_target(campaign_id, 2000);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

#[test]
#[should_panic(expected: 'Error: Campaign has donations')]
fn test_update_campaign_target_with_donations() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;

    // Create campaign and make donation
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('Test', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Approve and donate
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(token_address);

    // Make donation in separate block
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    campaign_donation.donate_to_campaign(campaign_id, 500);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Try to update target in separate block - this should fail since current_balance > 0
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    campaign_donation.update_campaign_target(campaign_id, 2000);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

#[test]
fn test_cancel_campaign_successful() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();

    // Create campaign
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('Test', 1000);

    // Cancel campaign
    campaign_donation.cancel_campaign(campaign_id);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Verify cancellation
    let campaign = campaign_donation.get_campaign(campaign_id);
    assert(campaign.is_closed, 'Campaign not closed');
    assert!(!campaign.is_goal_reached, "Campaign goal should not be reached");
}

#[test]
#[should_panic(expected: 'Error: Campaign closed')]
fn test_cancel_campaign_already_closed() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();

    // Create and cancel campaign
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('Test', 1000);
    campaign_donation.cancel_campaign(campaign_id);

    // Try to cancel again
    campaign_donation.cancel_campaign(campaign_id);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

#[test]
fn test_claim_refund_successful() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;

    // Create campaign
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('Test', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Make donation
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    campaign_donation.donate_to_campaign(campaign_id, 500);

    // Cancel campaign
    campaign_donation.cancel_campaign(campaign_id);

    // Claim refund
    let balance_before = token_dispatcher.balance_of(sender);
    campaign_donation.claim_refund(campaign_id);
    let balance_after = token_dispatcher.balance_of(sender);

    stop_cheat_caller_address(campaign_donation.contract_address);

    // Verify refund
    assert(balance_after - balance_before == 500, 'Refund amount incorrect');
    let campaign = campaign_donation.get_campaign(campaign_id);
    assert(campaign.is_cancelled, 'Campaign not cancelled');
}

#[test]
#[should_panic(expected: 'Error: Refund already claimed')]
fn test_claim_refund_twice() {
    let (token_address, sender, campaign_donation, _erc721) = setup();

    // Create campaign and make donation
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('Test', 1000);
    stop_cheat_caller_address(campaign_donation.contract_address);

    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    campaign_donation.donate_to_campaign(campaign_id, 500);
    // Cancel and claim refund
    campaign_donation.cancel_campaign(campaign_id);
    campaign_donation.claim_refund(campaign_id);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Try to claim again
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    campaign_donation.claim_refund(campaign_id);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

#[test]
#[should_panic(expected: 'Error: Donation not found')]
fn test_claim_refund_no_donation() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();
    let other_user: ContractAddress = contract_address_const::<'other_user'>();

    // Create campaign
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id = campaign_donation.create_campaign('Test', 1000);

    // Cancel campaign
    campaign_donation.cancel_campaign(campaign_id);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Try to claim refund as non-donor
    start_cheat_caller_address(campaign_donation.contract_address, other_user);
    campaign_donation.claim_refund(campaign_id);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

#[test]
fn test_mint_donation_receipt_successful() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();
    // Deploy the Donation NFT contract
    let (erc721, donation_nft_dispatcher) = deploy_donation_nft(campaign_donation.contract_address);
    // Use the protocol owner to set the donation NFT address
    // in the campaign donation contract
    let protocol_owner: ContractAddress = contract_address_const::<'protocol_owner'>();
    // Set the donation NFT address in the campaign donation contract
    start_cheat_caller_address(campaign_donation.contract_address, protocol_owner);
    campaign_donation.set_donation_nft_address(donation_nft_dispatcher.contract_address);
    stop_cheat_caller_address(campaign_donation.contract_address);
    let target_amount = 1000_u256;
    let campaign_ref = 'Test';
    let owner = contract_address_const::<'owner'>();

    start_cheat_caller_address(campaign_donation.contract_address, owner);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount);

    // Simulate delegate's approval:
    start_cheat_caller_address(_token_address, sender);
    IERC20Dispatcher { contract_address: _token_address }
        .approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(_token_address);

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let donation_id = campaign_donation.donate_to_campaign(campaign_id, 500);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Mint the receipt NFT
    start_cheat_caller_address(campaign_donation.contract_address, sender);

    let receipt_token_id = campaign_donation.mint_donation_nft(campaign_id, donation_id);
    stop_cheat_caller_address(campaign_donation.contract_address);
    // Check if the NFT was minted successfull
    assert(receipt_token_id > 0_u256, 'NFT minting failed');
    // Verify the Donation Metadata
    let donation_metadata = DonationMetadata {
        campaign_id: campaign_id,
        donation_id: donation_id,
        donor: sender,
        amount: 500_u256,
        timestamp: starknet::get_block_timestamp(),
        campaign_name: campaign_ref,
        campaign_owner: owner,
    };
    let receipt_data = donation_nft_dispatcher.get_donation_data(receipt_token_id);
    assert(
        receipt_data.campaign_id == donation_metadata.campaign_id, 'Campaign ID mismatch in NFT',
    );
    assert(
        receipt_data.donation_id == donation_metadata.donation_id, 'Donation ID mismatch in NFT',
    );
    assert(receipt_data.donor == donation_metadata.donor, 'Donor mismatch in NFT');
    assert(receipt_data.amount == donation_metadata.amount, 'Amount mismatch in NFT');
    assert(receipt_data.timestamp == donation_metadata.timestamp, 'Timestamp mismatch in NFT');
    assert(
        receipt_data.campaign_name == donation_metadata.campaign_name,
        'Campaign name mismatch in NFT',
    );
    assert(
        receipt_data.campaign_owner == donation_metadata.campaign_owner,
        'Campaign owner mismatch in NFT',
    );
    // Verify the NFT ownership
    let owner_of_nft = erc721.owner_of(receipt_token_id);
    assert(owner_of_nft == sender, 'NFT ownership mismatch');
}

#[test]
#[should_panic(expected: 'Error: Caller is not the donor')]
fn test_mint_donation_receipt_fail_if_not_donor() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();
    // Deploy the Donation NFT contract
    let (_erc721, donation_nft_dispatcher) = deploy_donation_nft(
        campaign_donation.contract_address,
    );
    let protocol_owner: ContractAddress = contract_address_const::<'protocol_owner'>();
    // Set the donation NFT address in the campaign donation contract
    start_cheat_caller_address(campaign_donation.contract_address, protocol_owner);
    campaign_donation.set_donation_nft_address(donation_nft_dispatcher.contract_address);
    stop_cheat_caller_address(campaign_donation.contract_address);
    let target_amount = 1000_u256;
    let campaign_ref = 'Test';
    let owner = contract_address_const::<'owner'>();

    start_cheat_caller_address(campaign_donation.contract_address, owner);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount);

    // Simulate delegate's approval:
    start_cheat_caller_address(_token_address, sender);
    IERC20Dispatcher { contract_address: _token_address }
        .approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(_token_address);

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let donation_id = campaign_donation.donate_to_campaign(campaign_id, 500);
    stop_cheat_caller_address(campaign_donation.contract_address);
    // Mint the receipt NFT
    // Should panic because the owner contract is not the donor
    start_cheat_caller_address(campaign_donation.contract_address, owner);
    campaign_donation.mint_donation_nft(campaign_id, donation_id);
    stop_cheat_caller_address(campaign_donation.contract_address);
}

#[test]
#[should_panic(expected: 'NFT already minted')]
fn test_mint_donation_receipt_fail_if_already_minted() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();
    // Deploy the Donation NFT contract
    let (_erc721, donation_nft_dispatcher) = deploy_donation_nft(
        campaign_donation.contract_address,
    );
    // Use the protocol owner to set the donation NFT address
    // in the campaign donation contract
    let protocol_owner: ContractAddress = contract_address_const::<'protocol_owner'>();
    // Set the donation NFT address in the campaign donation contract
    start_cheat_caller_address(campaign_donation.contract_address, protocol_owner);
    campaign_donation.set_donation_nft_address(donation_nft_dispatcher.contract_address);
    stop_cheat_caller_address(campaign_donation.contract_address);
    let target_amount = 1000_u256;
    let campaign_ref = 'Test';
    let owner = contract_address_const::<'owner'>();

    start_cheat_caller_address(campaign_donation.contract_address, owner);
    let campaign_id = campaign_donation.create_campaign(campaign_ref, target_amount);

    // Simulate delegate's approval:
    start_cheat_caller_address(_token_address, sender);
    IERC20Dispatcher { contract_address: _token_address }
        .approve(campaign_donation.contract_address, 1000);
    stop_cheat_caller_address(_token_address);

    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let donation_id = campaign_donation.donate_to_campaign(campaign_id, 500);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Mint the receipt NFT for the first time
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    campaign_donation.mint_donation_nft(campaign_id, donation_id);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Try to mint the receipt NFT again for the same donation
    start_cheat_caller_address(campaign_donation.contract_address, sender);

    campaign_donation.mint_donation_nft(campaign_id, donation_id);
}

#[test]
#[should_panic(expected: 'Donation data not found')]
fn test_get_donation_data_fail_if_not_found() {
    let (_token_address, _sender, campaign_donation, _erc721) = setup();
    // Deploy the Donation NFT contract
    let (_erc721, donation_nft_dispatcher) = deploy_donation_nft(
        campaign_donation.contract_address,
    );

    // Try to get donation data for a non-existent token ID
    donation_nft_dispatcher.get_donation_data(999_u256);
}
fn test_get_donations_by_donor_no_donations() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();

    // Fetch donations for sender
    let donations = campaign_donation.get_donations_by_donor(sender);
    assert(donations.len() == 0, 'Should have no donations');
}

#[test]
fn test_get_donations_by_donor_single_donation() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;

    // Create new campaign
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id: u256 = campaign_donation.create_campaign('Campaign1', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Approve token transfer for campaign contract
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, target_amount);
    stop_cheat_caller_address(token_address);

    // Make a single donation
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let amount_1 = 50_u256;
    campaign_donation.donate_to_campaign(campaign_id, amount_1);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Fetch donations for sender
    let donations = campaign_donation.get_donations_by_donor(sender);
    assert(donations.len() == 1, 'Should have one donation');

    // Verify donation details
    let (stored_campaign_id, stored_donation) = donations.at(0);
    assert(*stored_campaign_id == campaign_id, 'Campaign id mismatch');
    assert(*stored_donation.donor == sender, 'Donor mismatch');
    assert(*stored_donation.amount == amount_1, 'Amount mismatch');
}

#[test]
fn test_get_donations_by_donor_across_multiple_campaigns() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;

    // Create two campaigns
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id_1: u256 = campaign_donation.create_campaign('Campaign1', target_amount);
    let campaign_id_2: u256 = campaign_donation.create_campaign('Campaign2', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Approve token transfer for campaign contract
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, target_amount);
    stop_cheat_caller_address(token_address);

    // Donate to campaign 1
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let amount_1 = 100_u256;
    campaign_donation.donate_to_campaign(campaign_id_1, amount_1);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Donate to campaign 2
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let amount_2 = 200_u256;
    campaign_donation.donate_to_campaign(campaign_id_2, amount_2);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Fetch all donations for sender
    let donations = campaign_donation.get_donations_by_donor(sender);
    assert(donations.len() == 2, 'Should have two donations');

    // Verify first tuple
    let (stored_campaign_id, stored_donation) = donations.at(0);
    assert(*stored_campaign_id == campaign_id_1, 'Campaign id mismatch');
    assert(*stored_donation.donor == sender, 'Donor mismatch');
    assert(*stored_donation.amount == amount_1, 'Amount mismatch');

    // Verify second tuple
    let (stored_campaign_id, stored_donation) = donations.at(1);
    assert(*stored_campaign_id == campaign_id_2, 'Campaign id mismatch');
    assert(*stored_donation.donor == sender, 'Donor mismatch');
    assert(*stored_donation.amount == amount_2, 'Amount mismatch');
}

#[test]
fn test_get_donations_by_donor_multiple_donations() {
    let (token_address, sender, campaign_donation, _erc721) = setup();
    let target_amount = 1000_u256;

    // Create new campaign
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id: u256 = campaign_donation.create_campaign('Campaign1', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Approve token transfer for campaign contract
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, target_amount);
    stop_cheat_caller_address(token_address);

    // Make two donations
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let amount_1 = 50_u256;
    campaign_donation.donate_to_campaign(campaign_id, amount_1);
    let amount_2 = 10_u256;
    campaign_donation.donate_to_campaign(campaign_id, amount_2);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Fetch donations for sender
    let donations = campaign_donation.get_donations_by_donor(sender);
    assert(donations.len() == 2, 'Should have two donations');

    // Verify first donation
    let (stored_campaign_id, stored_donation) = donations.at(0);
    assert(*stored_campaign_id == campaign_id, 'Campaign id mismatch');
    assert(*stored_donation.donor == sender, 'Donor mismatch');
    assert(*stored_donation.amount == amount_1, 'Amount mismatch');

    // Verify second donation
    let (stored_campaign_id, stored_donation) = donations.at(1);
    assert(*stored_campaign_id == campaign_id, 'Campaign id mismatch');
    assert(*stored_donation.donor == sender, 'Donor mismatch');
    assert(*stored_donation.amount == amount_2, 'Amount mismatch');
}

#[test]
fn test_get_total_donated_by_donor_no_donations() {
    let (_token_address, sender, campaign_donation, _erc721) = setup();

    // Fetch total donated for sender
    let total_donated = campaign_donation.get_total_donated_by_donor(sender);

    // Verify donor has donated nothing
    assert(total_donated == 0, 'Should have no donations');
}

#[test]
fn test_get_total_donated_by_donor_single_donation() {
    let (token_address, sender, campaign_donation, _erc721) = setup();

    // Create new campaign
    let target_amount = 1000_u256;
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id: u256 = campaign_donation.create_campaign('Campaign1', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Approve token transfer for campaign contract
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, target_amount);
    stop_cheat_caller_address(token_address);

    // Make a single donation
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let amount_1 = 50_u256;
    campaign_donation.donate_to_campaign(campaign_id, amount_1);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Fetch total donated for sender
    let total_donated = campaign_donation.get_total_donated_by_donor(sender);

    // Verify total donated equals the donation amount
    assert(total_donated == amount_1, 'Total donated doesnt match');
}

#[test]
fn test_get_total_donated_by_donor_multiple_donations_same_campaign() {
    let (token_address, sender, campaign_donation, _erc721) = setup();

    // Create new campaign
    let target_amount = 1000_u256;
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id: u256 = campaign_donation.create_campaign('Campaign1', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Approve token transfer for campaign contract
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, target_amount);
    stop_cheat_caller_address(token_address);

    // Make two donations to the same campaign
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let amount_1 = 50_u256;
    campaign_donation.donate_to_campaign(campaign_id, amount_1);
    let amount_2 = 10_u256;
    campaign_donation.donate_to_campaign(campaign_id, amount_2);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Fetch total donated for sender
    let total_donated = campaign_donation.get_total_donated_by_donor(sender);

    // Verify total donated equals sum of both amounts
    assert(total_donated == amount_1 + amount_2, 'Total donated doesnt match');
}

#[test]
fn test_get_total_donated_by_donor_across_multiple_campaigns() {
    let (token_address, sender, campaign_donation, _erc721) = setup();

    // Create two campaigns
    let target_amount = 1000_u256;
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id_1: u256 = campaign_donation.create_campaign('Campaign1', target_amount);
    let campaign_id_2: u256 = campaign_donation.create_campaign('Campaign2', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Approve token transfer for campaign contract
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, target_amount);
    stop_cheat_caller_address(token_address);

    // Make donations to both campaigns
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let amount_1 = 100_u256;
    campaign_donation.donate_to_campaign(campaign_id_1, amount_1);
    let amount_2 = 200_u256;
    campaign_donation.donate_to_campaign(campaign_id_1, amount_2);
    let amount_3 = 300_u256;
    campaign_donation.donate_to_campaign(campaign_id_2, amount_3);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Fetch total donated for sender
    let total_donated = campaign_donation.get_total_donated_by_donor(sender);

    // Verify total donated equals sum of all amounts
    assert(total_donated == amount_1 + amount_2 + amount_3, 'Total donated doesnt match');
}

#[test]
fn test_has_donated_to_campaign_single_donation() {
    let (token_address, sender, campaign_donation, _erc721) = setup();

    // Check that sender has not donated to nonexistent campaign
    let nonexistent_campaign_id = 42;
    let has_donated = campaign_donation.has_donated_to_campaign(nonexistent_campaign_id, sender);
    assert(!has_donated, 'No donation');

    // Create new campaign
    let target_amount = 1000_u256;
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let campaign_id: u256 = campaign_donation.create_campaign('Campaign1', target_amount);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Check that sender has not donated to newly created campaign
    let has_donated = campaign_donation.has_donated_to_campaign(campaign_id, sender);
    assert(!has_donated, 'No donation');

    // Approve token transfer for campaign contract
    let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
    start_cheat_caller_address(token_address, sender);
    token_dispatcher.approve(campaign_donation.contract_address, target_amount);
    stop_cheat_caller_address(token_address);

    // Make a single donation
    start_cheat_caller_address(campaign_donation.contract_address, sender);
    let amount_1 = 50_u256;
    campaign_donation.donate_to_campaign(campaign_id, amount_1);
    stop_cheat_caller_address(campaign_donation.contract_address);

    // Check that sender has donated to campaign
    let has_donated = campaign_donation.has_donated_to_campaign(campaign_id, sender);
    assert(has_donated, 'Donation exists');
}
