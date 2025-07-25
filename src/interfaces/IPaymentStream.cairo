use starknet::ContractAddress;
use crate::base::types::{ProtocolMetrics, Stream, StreamMetrics};

/// @title IPaymentStream
/// @notice Creates and manages payment streams with linear streaming functions.
#[starknet::interface]
pub trait IPaymentStream<TContractState> {
    /// @notice Creates a new stream by setting the start time and wrapping it in an NFT.
    /// @param recipient The address receiving the tokens
    /// @param total_amount The total amount to be streamed
    /// @param start_time The timestamp when the stream starts
    /// @param end_time The timestamp when the stream ends
    /// @param cancelable Boolean indicating if the stream can be canceled
    /// @param token The contract address of the ERC-20 token to be streamed
    /// @param transferable Boolean indicating if the stream can be transferred
    /// @return The ID of the newly created stream
    fn create_stream(
        ref self: TContractState,
        recipient: ContractAddress,
        total_amount: u256,
        duration: u64,
        cancelable: bool,
        token: ContractAddress,
        transferable: bool,
    ) -> u256;

    /// @notice Deposits the provided amount to the stream
    /// @param stream_id The ID of the stream to deposit to
    /// @param amount The amount to deposit
    // fn deposit(ref self: TContractState, stream_id: u256, amount: u256);

    /// @notice Deposit and Pause the stream
    /// @param stream_id The ID of the stream to deposit and pause
    /// @param amount The amount to deposit
    // fn deposit_and_pause(ref self: TContractState, stream_id: u256, amount: u256);

    /// @notice Withdraws the provided amount minus the protocol fee to the provided address
    /// @param stream_id The ID of the stream to withdraw from
    /// @param amount The amount to withdraw
    /// @param to The address receiving the withdrawn tokens
    /// @return A tuple of (withdrawn_amount, protocol_fee_amount)
    fn withdraw(
        ref self: TContractState, stream_id: u256, amount: u256, to: ContractAddress,
    ) -> (u128, u128);

    /// @notice Withdraws the entire withdrawable amount minus the protocol fee
    /// @param stream_id The ID of the stream to withdraw from
    /// @param to The address receiving the withdrawn tokens
    /// @return A tuple of (withdrawn_amount, protocol_fee_amount)
    fn withdraw_max(ref self: TContractState, stream_id: u256, to: ContractAddress) -> (u128, u128);

    /// @notice updates the fee collector address
    /// @param new_fee_collector The new contract address to hold fees collected
    fn update_fee_collector(ref self: TContractState, new_fee_collector: ContractAddress);

    /// @notice updates the protocol owner address
    /// @param new_protocol_owner The new protocol owner's address
    fn update_protocol_owner(ref self: TContractState, new_protocol_owner: ContractAddress);

    /// @notice returns the fee collector address
    fn get_fee_collector(self: @TContractState) -> ContractAddress;

    /// @notice Cancels the stream
    /// @param stream_id The ID of the stream to cancel
    fn cancel(ref self: TContractState, stream_id: u256);

    /// @notice Pauses the stream
    /// @param stream_id The ID of the stream to pause
    fn pause(ref self: TContractState, stream_id: u256);

    /// @notice Restarts the stream with the provided rate per second
    /// @param stream_id The ID of the stream to restart
    /// @param rate_per_second The amount by which the debt increases every second
    fn restart(ref self: TContractState, stream_id: u256);

    /// @notice Returns the stream data for the given ID
    /// @param stream_id The stream ID for the query
    /// @return The Stream struct containing all stream data
    fn get_stream(self: @TContractState, stream_id: u256) -> Stream;

    /// @notice Calculates the amount that the recipient can withdraw
    /// @param stream_id The stream ID for the query
    /// @return The amount that can be withdrawn
    fn get_withdrawable_amount(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Returns whether the stream is currently active
    /// @param stream_id The stream ID for the query
    /// @return Boolean indicating if the stream is active
    fn is_stream_active(self: @TContractState, stream_id: u256) -> bool;

    /// @notice Returns the time at which the stream will be depleted
    /// @param stream_id The stream ID for the query
    /// @return The timestamp when the stream will be depleted
    fn get_depletion_time(self: @TContractState, stream_id: u256) -> u64;

    /// @notice Returns the total amount owed by the sender to the recipient
    /// @param stream_id The stream ID for the query
    /// @return The total debt amount
    fn get_total_debt(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Returns the amount of debt not covered by the stream balance
    /// @param stream_id The stream ID for the query
    /// @return The uncovered debt amount
    fn get_uncovered_debt(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Returns the amount of debt covered by the stream balance
    /// @param stream_id The stream ID for the query
    /// @return The covered debt amount
    fn get_covered_debt(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Returns the amount that the sender can be refunded
    /// @param stream_id The stream ID for the query
    /// @return The refundable amount
    // fn get_refundable_amount(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Returns the total number of currently active streams
    /// @return The count of active streams in the protocol
    fn get_active_streams_count(self: @TContractState) -> u256;

    /// @notice Returns the token decimals
    /// @params stream_id The unique identifier of the stream
    /// @return Token decimals
    fn get_token_decimals(self: @TContractState, stream_id: u256) -> u8;

    /// @notice Retrieves the analytics metrics for a specific stream
    /// @param stream_id The unique identifier of the stream
    /// @return StreamMetrics containing detailed stream analytics
    fn get_stream_metrics(self: @TContractState, stream_id: u256) -> StreamMetrics;

    /// @notice Retrieves overall protocol-level streaming metrics
    /// @return ProtocolMetrics containing comprehensive protocol analytics
    fn get_protocol_metrics(self: @TContractState) -> ProtocolMetrics;

    /// @notice Delegate a stream to a new recipient
    /// @param stream_id The stream ID for the query
    /// @param delegate The address to delegate a stream to
    /// @return Boolean indicating if the stream delegation is successsful
    fn delegate_stream(
        ref self: TContractState, stream_id: u256, delegate: ContractAddress,
    ) -> bool;

    /// @notice Revoke a delegation on a stream
    /// @param stream_id The stream ID for the query
    /// @return Boolean indicating if the stream delegation is revoked
    fn revoke_delegation(ref self: TContractState, stream_id: u256) -> bool;

    /// @notice returns the delegated address from a stream
    fn get_stream_delegate(self: @TContractState, stream_id: u256) -> ContractAddress;

    /// @notice Transfers the stream to a new recipient
    /// @param stream_id The ID of the stream to transfer
    /// @param new_recipient The address of the new recipient
    fn transfer_stream(ref self: TContractState, stream_id: u256, new_recipient: ContractAddress);

    /// @notice Sets the transferability of the stream
    /// @param stream_id The ID of the stream to update
    /// @param transferable Boolean indicating if the stream can be transferred
    fn set_transferability(ref self: TContractState, stream_id: u256, transferable: bool);


    /// @notice Allow authorized addresses to collect revenue for a specific token.
    /// @param token The ContractAddress of the token
    /// @param to The ContractAddress that will receive the revenue
    // fn collect_protocol_revenue(
    //     ref self: TContractState, token: ContractAddress, to: ContractAddress,
    // );

    /// @notice Check if a stream exists
    /// @param stream_id The ID of the stream
    /// @return Boolean indicating if the stream exists
    fn is_stream(self: @TContractState, stream_id: u256) -> bool;

    /// @notice Check if a stream is paused
    /// @param stream_id The ID of the stream
    /// @return Boolean indicating if the stream is paused
    fn is_paused(self: @TContractState, stream_id: u256) -> bool;

    /// @notice gets sender of the stream
    /// @param stream_id The ID of the stream
    /// @return contract address of the sender
    fn get_sender(self: @TContractState, stream_id: u256) -> ContractAddress;


    /// @notice get recipient of a stream
    /// @param stream_id The ID of the stream
    /// @return contract address of the recipient
    fn get_recipient(self: @TContractState, stream_id: u256) -> ContractAddress;


    /// @notice gets the toke of a stream
    /// @param stream_id The ID of the stream
    /// @return token address of the stream
    fn get_token(self: @TContractState, stream_id: u256) -> ContractAddress;


    /// @notice gets the rate per second of a stream
    /// @param stream_id The ID of the stream
    /// @return rate per second associated with the stream
    fn get_rate_per_second(self: @TContractState, stream_id: u256) -> u256;

    /// @notice Retrieves the sum of balances of all streams
    /// @param token The ERC-20 token to query
    /// @return The aggregated balance across all streams
    fn get_aggregate_balance(self: @TContractState, token: ContractAddress) -> u256;

    /// @notice Emitted when the contract admin recovers the surplus amount of token
    /// @param token The address of the token the surplus amount has been recovered for
    /// @param to The address the surplus amount has been sent to
    /// @return surplus The amount of surplus tokens recovered
    fn recover(ref self: TContractState, token: ContractAddress, to: ContractAddress) -> u256;

    /// @notice Sets the protocol fee rate for a specific token
    /// @param token The token address to set the fee rate for
    /// @param new_fee_rate The new fee rate in fixed-point (e.g., 0.01 for 1%)
    fn set_protocol_fee_rate(ref self: TContractState, token: ContractAddress, new_fee_rate: u64);

    /// @notice Gets the protocol fee rate for a specific token
    /// @param token The token address to get the fee rate for
    /// @return The current fee rate in fixed-point
    fn get_protocol_fee_rate(self: @TContractState, token: ContractAddress) -> u64;

    /// @notice Sets the general protocol fee rate
    /// @param new_general_protocol_fee_rate The new fee rate in fixed-point
    fn set_general_protocol_fee_rate(ref self: TContractState, new_general_protocol_fee_rate: u64);

    /// @notice Gets the general protocol fee rate
    /// @return The current fee rate in fixed-point
    fn get_general_protocol_fee_rate(self: @TContractState) -> u64;
}
