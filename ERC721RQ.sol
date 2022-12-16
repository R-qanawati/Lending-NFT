// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/ERC721.sol)

//ERC721RQ (@Official_Chonii) (Token Lending implementation built on top of OpenZeppelins ERC721) 
//Created by: RQ#9126

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721RQ is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    enum State { AWAITING_PAYMENT, PENDING_END_OF_LEASE, COMPLETE }

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    //Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    //Mapping state to tokenID
    mapping(uint256 => State) private _stateOfID;

    //Mapping eth payable amount to tokenID
    mapping(uint256 => uint256) private _ethAmount;

    //Mapping total days of lease to tokenID
    mapping(uint256 => uint256) private _totalDays;
    
    //Mapping time lease started to tokenID
    mapping(uint256 => uint256) private _timeStarted;

    //Mapping temporary owners (Lendees)
    mapping(uint256 => address) private _lendees;

    //Bool value to check if lent
    mapping(uint256 => bool) private _isLent;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    // Only the Lendee can call
    modifier onlyERC721RQLendee(uint256 _tokenId) {
        require(msg.sender == _lendees[_tokenId] || _lendees[_tokenId] == 0x0000000000000000000000000000000000000000, "Only lendee can call this method");
        _;
    }

    // Only after the lending period has ended
    modifier endOfLease(uint256 _tokenId) {
        require(block.timestamp >= (_timeStarted[_tokenId] + (_totalDays[_tokenId] * 86400)), "Lending period hasn't ended!");
        _;
    }

    // Function to lease ERC721RQ for a set length of days to a specific wallet address willing to pay the eth value (can be 0)
    function leaseDetailedERC721RQ(address _Lendee, uint256 _tokenId, uint256 _ethValue, uint256 _lengthOfDays) public virtual {
        address owner = _owners[_tokenId];
        require(msg.sender == owner, "ERC721RQ: msg.sender is not the owner");
        require(msg.sender != _Lendee, "ERC721RQ: lending to yourself?");
        require(_stateOfID[_tokenId] != State.PENDING_END_OF_LEASE, "You are currently leasing");

        _lendees[_tokenId] = _Lendee;
        _stateOfID[_tokenId] = State.AWAITING_PAYMENT;
        _ethAmount[_tokenId] = (_ethValue * 10 ** 18);
        _totalDays[_tokenId] = _lengthOfDays;
    }

    // Function to lease ERC721RQ for a set length of days to any wallet willing to pay the ETH value (can be 0)
    function leaseERC721RQ(uint256 _tokenId, uint256 _ethValue, uint256 _lengthOfDays) public virtual {
        address owner = _owners[_tokenId];
        require(msg.sender == owner, "ERC721RQ: msg.sender is not the owner");
        require(_stateOfID[_tokenId] != State.PENDING_END_OF_LEASE, "You are currently leasing");

        _stateOfID[_tokenId] = State.AWAITING_PAYMENT;
        _ethAmount[_tokenId] = (_ethValue * 10 ** 18);
        _totalDays[_tokenId] = _lengthOfDays;
    }

    // Function for the Lendee to pay the required amount of eth for specific token id
    function payToLease(uint256 _tokenId) onlyERC721RQLendee(_tokenId) public payable virtual
    {
        require(_stateOfID[_tokenId] == State.AWAITING_PAYMENT, "Already paid");
        require(msg.value >= _ethAmount[_tokenId], "Amount is incorrect");

        if(_lendees[_tokenId] == 0x0000000000000000000000000000000000000000)
        {
            _lendees[_tokenId] = msg.sender;
        }

        payable(_owners[_tokenId]).transfer(_ethAmount[_tokenId]);
        _stateOfID[_tokenId] = State.PENDING_END_OF_LEASE;
        _timeStarted[_tokenId] = block.timestamp;
        _isLent[_tokenId] = true;
    }

    // Lender can call this function after period has ended to retrieve ethereum and token ownership
    function endLease(uint256 _tokenId) endOfLease(_tokenId) public virtual {
        address owner = _owners[_tokenId];
        require(msg.sender == owner, "ERC721RQ: msg.sender is not the owner");

        if(_stateOfID[_tokenId] == State.PENDING_END_OF_LEASE)
        {
            _lendees[_tokenId] = 0x0000000000000000000000000000000000000000;
            _stateOfID[_tokenId] = State.COMPLETE;
            _isLent[_tokenId] = false;
        }
    }

    // Reset lending period if NFT is not lent
    function resetStateLending(uint256 _tokenId) internal
    {
        _stateOfID[_tokenId] = State.COMPLETE;
        _ethAmount[_tokenId] = 0;
        _totalDays[_tokenId] = 0;
        _timeStarted[_tokenId] = 0;
        _lendees[_tokenId] = 0x0000000000000000000000000000000000000000;
    }

    function stateOfTokenID(uint256 _tokenId) public view returns(State)
    {
        return _stateOfID[_tokenId];
    }

    function checkLendee(uint256 _tokenId) public view returns(address)
    {
        return _lendees[_tokenId];
    }

    function checkethAmount(uint256 _tokenId) public view returns(uint256)
    {
        return _ethAmount[_tokenId];
    }

    function checkLengthOfLease(uint256 _tokenId) public view returns(uint256)
    {
        return _totalDays[_tokenId];
    }

    function checkLeaseStartTime(uint256 _tokenId) public view returns(uint256)
    {
        return _timeStarted[_tokenId];
    }

    function checkIfLent(uint256 _tokenId) public view returns(bool)
    {
        return _isLent[_tokenId];
    }


    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721RQ: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721RQ: owner query for nonexistent token");

        if(_isLent[tokenId])
        {
            owner = _lendees[tokenId];
        }

        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = _owners[tokenId];
        require(to != owner, "ERC721RQ: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721RQ: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721RQ: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    
    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721RQ: transfer caller is not owner nor approved");
        require(_isLent[tokenId] == false, "ERC721RQ: currently in a lending contract");
        
        if(_stateOfID[tokenId] == State.AWAITING_PAYMENT)
        {
           resetStateLending(tokenId);
        }

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721RQ: transfer caller is not owner nor approved");
        require(_isLent[tokenId] == false, "ERC721RQ: currently in a lending contract");

        if(_stateOfID[tokenId] == State.AWAITING_PAYMENT)
        {
           resetStateLending(tokenId);
        }

        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        require(_isLent[tokenId] == false, "ERC721RQ: currently in a lending contract");

        if(_stateOfID[tokenId] == State.AWAITING_PAYMENT)
        {
           resetStateLending(tokenId);
        }

        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721RQ: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721RQ: operator query for nonexistent token");
        address owner = _owners[tokenId];
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721RQ: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721RQ: mint to the zero address");
        require(!_exists(tokenId), "ERC721RQ: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = _owners[tokenId];

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(_owners[tokenId] == from, "ERC721RQ: transfer from incorrect owner");
        require(to != address(0), "ERC721RQ: transfer to the zero address");
        require(_isLent[tokenId] == false, "ERC721RQ: currently in a lending contract");

        if(_stateOfID[tokenId] == State.AWAITING_PAYMENT)
        {
           resetStateLending(tokenId);
        }

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);

        
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(_owners[tokenId], to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721RQ: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721RQ: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}