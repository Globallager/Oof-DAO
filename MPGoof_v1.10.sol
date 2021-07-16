// SPDX-License-Identifier: Unlicense
/** MIT Licenses of code used in Money Printer Goes Oof
 * 
 * Copyright (c) 2020 zOS Global Limited
 * Copyright (c) 2020 https://github.com/horizon-games
 * Copyright (c) 2020 OpenSea
 *
 *Permission is hereby granted, free of charge, to any person obtaining a copy of
 *this software and associated documentation files (the "Software"), to deal in
 *the Software without restriction, including without limitation the rights to
 *use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 *the Software, and to permit persons to whom the Software is furnished to do so,
 *subject to the following conditions:
 *
 *The above copyright notice and this permission notice shall be included in all
 *copies or substantial portions of the Software.
 *
 *THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 *FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 *COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 *IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 *CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

pragma solidity ^0.7.4;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/GSN/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/arcadeum/multi-token-standard/blob/master/contracts/utils/Address.sol";
import "https://github.com/arcadeum/multi-token-standard/blob/master/contracts/utils/ERC165.sol";
import "https://github.com/arcadeum/multi-token-standard/blob/master/contracts/interfaces/IERC1155.sol";
import "https://github.com/arcadeum/multi-token-standard/blob/master/contracts/interfaces/IERC1155Metadata.sol";
import "https://github.com/arcadeum/multi-token-standard/blob/master/contracts/interfaces/IERC1155TokenReceiver.sol";

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev Give an account access to this role.
     */
    function add(Role storage role, address account) internal {
        require(!has(role, account), "Roles: account already has role");
        role.bearer[account] = true;
    }

    /**
     * @dev Remove an account's access to this role.
     */
    function remove(Role storage role, address account) internal {
        require(has(role, account), "Roles: account does not have role");
        role.bearer[account] = false;
    }

    /**
     * @dev Check if an account has this role.
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0), "Roles: account is the zero address");
        return role.bearer[account];
    }
}

/**
 * @title TokeniserRole
 * @dev Tokenisers are capable of creating and minting tokens.
 */
contract TokeniserRole is Context {
    using Roles for Roles.Role;

    event TokeniserAdded(address indexed account);
    event TokeniserRemoved(address indexed account);

    Roles.Role private _Tokenisers;

    constructor () {
        _addTokeniser(_msgSender());
    }

    modifier onlyTokeniser() {
        require(TokeniserCheck(_msgSender()), "TokeniserRole: caller is not a whitelisted Tokeniser");
        _;
    }

    function TokeniserCheck(address account) public view returns (bool) {
        return _Tokenisers.has(account);
    }

    function renounceTokeniser() external {
        _removeTokeniser(_msgSender());
        emit TokeniserRemoved(_msgSender());
    }

    function _addTokeniser(address account) internal {
        _Tokenisers.add(account);
        emit TokeniserAdded(account);
    }

    function _removeTokeniser(address account) internal {
        _Tokenisers.remove(account);
        emit TokeniserRemoved(account);
    }
}

/**
 * @dev Implementation of Multi-Token Standard contract
 */
contract ERC1155 is IERC1155, ERC165 {
  using SafeMath for uint256;
  using Address for address;

  /***********************************|
  |        Variables and Events       |
  |__________________________________*/

  // onReceive function signatures
  bytes4 constant internal ERC1155_RECEIVED_VALUE = 0xf23a6e61;
  bytes4 constant internal ERC1155_BATCH_RECEIVED_VALUE = 0xbc197c81;

  // Objects balances
  mapping (address => mapping(uint256 => uint256)) internal balances;

  // Operator Functions
  mapping (address => mapping(address => bool)) internal operators;


  /***********************************|
  |     Public Transfer Functions     |
  |__________________________________*/

  /**
   * @notice Transfers amount amount of an _id from the _from address to the _to address specified
   * @param _from    Source address
   * @param _to      Target address
   * @param _id      ID of the token type
   * @param _amount  Transfered amount
   * @param _data    Additional data with no specified format, sent in call to `_to`
   */
  function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes memory _data)
    public override
  {
    require((msg.sender == _from) || isApprovedForAll(_from, msg.sender), "ERC1155#safeTransferFrom: INVALID_OPERATOR");
    require(_to != address(0),"ERC1155#safeTransferFrom: INVALID_RECIPIENT");
    // require(_amount <= balances[_from][_id]) is not necessary since checked with safemath operations

    _safeTransferFrom(_from, _to, _id, _amount);
    _callonERC1155Received(_from, _to, _id, _amount, gasleft(), _data);
  }

  /**
   * @notice Send multiple types of Tokens from the _from address to the _to address (with safety call)
   * @param _from     Source addresses
   * @param _to       Target addresses
   * @param _ids      IDs of each token type
   * @param _amounts  Transfer amounts per token type
   * @param _data     Additional data with no specified format, sent in call to `_to`
   */
  function safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data)
    external override
  {
    // Requirements
    require((msg.sender == _from) || isApprovedForAll(_from, msg.sender), "ERC1155#safeBatchTransferFrom: INVALID_OPERATOR");
    require(_to != address(0), "ERC1155#safeBatchTransferFrom: INVALID_RECIPIENT");

    _safeBatchTransferFrom(_from, _to, _ids, _amounts);
    _callonERC1155BatchReceived(_from, _to, _ids, _amounts, gasleft(), _data);
  }


  /***********************************|
  |    Internal Transfer Functions    |
  |__________________________________*/

  /**
   * @notice Transfers amount amount of an _id from the _from address to the _to address specified
   * @param _from    Source address
   * @param _to      Target address
   * @param _id      ID of the token type
   * @param _amount  Transfered amount
   */
  function _safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount)
    internal
  {
    // Update balances
    balances[_from][_id] = balances[_from][_id].sub(_amount); // Subtract amount
    balances[_to][_id] = balances[_to][_id].add(_amount);     // Add amount

    // Emit event
    emit TransferSingle(msg.sender, _from, _to, _id, _amount);
  }

  /**
   * @notice Verifies if receiver is contract and if so, calls (_to).onERC1155Received(...)
   */
  function _callonERC1155Received(address _from, address _to, uint256 _id, uint256 _amount, uint256 _gasLimit, bytes memory _data)
    internal
  {
    // Check if recipient is contract
    if (_to.isContract()) {
      bytes4 retval = IERC1155TokenReceiver(_to).onERC1155Received{gas: _gasLimit}(msg.sender, _from, _id, _amount, _data);
      require(retval == ERC1155_RECEIVED_VALUE, "ERC1155#_callonERC1155Received: INVALID_ON_RECEIVE_MESSAGE");
    }
  }

  /**
   * @notice Send multiple types of Tokens from the _from address to the _to address (with safety call)
   * @param _from     Source addresses
   * @param _to       Target addresses
   * @param _ids      IDs of each token type
   * @param _amounts  Transfer amounts per token type
   */
  function _safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts)
    internal
  {
    require(_ids.length == _amounts.length, "ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");

    // Number of transfer to execute
    uint256 nTransfer = _ids.length;

    // Executing all transfers
    for (uint256 i = 0; i < nTransfer; i++) {
      // Update storage balance of previous bin
      balances[_from][_ids[i]] = balances[_from][_ids[i]].sub(_amounts[i]);
      balances[_to][_ids[i]] = balances[_to][_ids[i]].add(_amounts[i]);
    }

    // Emit event
    emit TransferBatch(msg.sender, _from, _to, _ids, _amounts);
  }

  /**
   * @notice Verifies if receiver is contract and if so, calls (_to).onERC1155BatchReceived(...)
   */
  function _callonERC1155BatchReceived(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts, uint256 _gasLimit, bytes memory _data)
    internal
  {
    // Pass data if recipient is contract
    if (_to.isContract()) {
      bytes4 retval = IERC1155TokenReceiver(_to).onERC1155BatchReceived{gas: _gasLimit}(msg.sender, _from, _ids, _amounts, _data);
      require(retval == ERC1155_BATCH_RECEIVED_VALUE, "ERC1155#_callonERC1155BatchReceived: INVALID_ON_RECEIVE_MESSAGE");
    }
  }


  /***********************************|
  |         Operator Functions        |
  |__________________________________*/

  /**
   * @notice Enable or disable approval for a third party ("operator") to manage all of caller's tokens
   * @param _operator  Address to add to the set of authorized operators
   * @param _approved  True if the operator is approved, false to revoke approval
   */
  function setApprovalForAll(address _operator, bool _approved)
    external override
  {
    // Update operator status
    operators[msg.sender][_operator] = _approved;
    emit ApprovalForAll(msg.sender, _operator, _approved);
  }

  /**
   * @notice Queries the approval status of an operator for a given owner
   * @param _owner     The owner of the Tokens
   * @param _operator  Address of authorized operator
   * @return isOperator True if the operator is approved, false if not
   */
  function isApprovedForAll(address _owner, address _operator)
    public override view returns (bool isOperator)
  {
    return operators[_owner][_operator];
  }


  /***********************************|
  |         Balance Functions         |
  |__________________________________*/

  /**
   * @notice Get the balance of an account's Tokens
   * @param _owner  The address of the token holder
   * @param _id     ID of the Token
   * @return The _owner's balance of the Token type requested
   */
  function balanceOf(address _owner, uint256 _id)
    external override view returns (uint256)
  {
    return balances[_owner][_id];
  }

  /**
   * @notice Get the balance of multiple account/token pairs
   * @param _owners The addresses of the token holders
   * @param _ids    ID of the Tokens
   * @return        The _owner's balance of the Token types requested (i.e. balance for each (owner, id) pair)
   */
  function balanceOfBatch(address[] memory _owners, uint256[] memory _ids)
    external override view returns (uint256[] memory)
  {
    require(_owners.length == _ids.length, "ERC1155#balanceOfBatch: INVALID_ARRAY_LENGTH");

    // Variables
    uint256[] memory batchBalances = new uint256[](_owners.length);

    // Iterate over each owner and token ID
    for (uint256 i = 0; i < _owners.length; i++) {
      batchBalances[i] = balances[_owners[i]][_ids[i]];
    }

    return batchBalances;
  }
}

/**
 * @notice Contract that handles metadata related methods.
 * @dev Methods assume a deterministic generation of URI based on token IDs.
 *      Methods also assume that URI uses hex representation of token IDs.
 */
contract ERC1155Metadata is IERC1155Metadata {
  // URI's default URI prefix
  string internal baseMetadataURI;

  /***********************************|
  |     Metadata Public Function s    |
  |__________________________________*/

  /**
   * @notice A distinct Uniform Resource Identifier (URI) for a given token.
   * @dev URIs are defined in RFC 3986.
   *      URIs are assumed to be deterministically generated based on token ID
   * @return URI string
   */
  function uri(uint256 _id) external override view returns (string memory) {
    return string(abi.encodePacked(baseMetadataURI, _uint2str(_id), ".json"));
  }

  /***********************************|
  |    Metadata Internal Functions    |
  |__________________________________*/

  /**
   * @notice Will update the base URL of token's URI
   * @param _newBaseMetadataURI New base URL of token's URI
   */
  function _setBaseMetadataURI(string memory _newBaseMetadataURI) internal {
    baseMetadataURI = _newBaseMetadataURI;
  }
  
  /***********************************|
  |    Utility Internal Functions     |
  |__________________________________*/
  
    /**
    * @notice Convert uint256 to string
    * @param _i Unsigned integer to convert to string
    */
    function _uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        
        uint256 j = _i;
        uint256 ii = _i;
        uint256 len;
        
        // Get number of bytes
        while (j != 0) {
            len++;
            j /= 10;
        }
        
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        
        // Get each individual ASCII
        while (ii != 0) {
            bstr[k--] = byte(uint8(48 + ii % 10));
            ii /= 10;
        }
        
        // Convert to string
        return string(bstr);
    }
}

/**
 * @dev Multi-Fungible Tokens with minting and burning methods. These methods assume
 *      a parent contract to be executed as they are `internal` functions
 */
contract ERC1155MintBurn is ERC1155 {
  using SafeMath for uint256;

  /****************************************|
  |            Minting Functions           |
  |_______________________________________*/

  /**
   * @notice Mint _amount of tokens of a given id
   * @param _to      The address to mint tokens to
   * @param _id      Token id to mint
   * @param _amount  The amount to be minted
   * @param _data    Data to pass if receiver is contract
   */
  function _mint(address _to, uint256 _id, uint256 _amount, bytes memory _data)
    internal
  {
    // Add _amount
    balances[_to][_id] = balances[_to][_id].add(_amount);

    // Emit event
    emit TransferSingle(msg.sender, address(0x0), _to, _id, _amount);

    // Calling onReceive method if recipient is contract
    _callonERC1155Received(address(0x0), _to, _id, _amount, gasleft(), _data);
  }

  /**
   * @notice Mint tokens for each ids in _ids
   * @param _to       The address to mint tokens to
   * @param _ids      Array of ids to mint
   * @param _amounts  Array of amount of tokens to mint per id
   * @param _data    Data to pass if receiver is contract
   */
  function _batchMint(address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data)
    internal
  {
    require(_ids.length == _amounts.length, "ERC1155MintBurn#batchMint: INVALID_ARRAYS_LENGTH");

    // Number of mints to execute
    uint256 nMint = _ids.length;

     // Executing all minting
    for (uint256 i = 0; i < nMint; i++) {
      // Update storage balance
      balances[_to][_ids[i]] = balances[_to][_ids[i]].add(_amounts[i]);
    }

    // Emit batch mint event
    emit TransferBatch(msg.sender, address(0x0), _to, _ids, _amounts);

    // Calling onReceive method if recipient is contract
    _callonERC1155BatchReceived(address(0x0), _to, _ids, _amounts, gasleft(), _data);
  }

  /****************************************|
  |            Burning Functions           |
  |_______________________________________*/

  /**
   * @notice Burn _amount of tokens of a given token id
   * @param _from    The address to burn tokens from
   * @param _id      Token id to burn
   * @param _amount  The amount to be burned
   */
  function _burn(address _from, uint256 _id, uint256 _amount)
    internal
  {
    //Substract _amount
    balances[_from][_id] = balances[_from][_id].sub(_amount);

    // Emit event
    emit TransferSingle(msg.sender, _from, address(0x0), _id, _amount);
  }

  /**
   * @notice Burn tokens of given token id for each (_ids[i], _amounts[i]) pair
   * @param _from     The address to burn tokens from
   * @param _ids      Array of token ids to burn
   * @param _amounts  Array of the amount to be burned
   */
  function _batchBurn(address _from, uint256[] memory _ids, uint256[] memory _amounts)
    internal
  {
    // Number of mints to execute
    uint256 nBurn = _ids.length;
    require(nBurn == _amounts.length, "ERC1155MintBurn#batchBurn: INVALID_ARRAYS_LENGTH");

    // Executing all minting
    for (uint256 i = 0; i < nBurn; i++) {
      // Update storage balance
      balances[_from][_ids[i]] = balances[_from][_ids[i]].sub(_amounts[i]);
    }

    // Emit batch mint event
    emit TransferBatch(msg.sender, _from, address(0x0), _ids, _amounts);
  }
}

/**
 * @title ERC1155Tradable
 * ERC1155Tradable - ERC1155 contract that has create and mint functionality, and supports useful standards from OpenZeppelin,
  like totalSupply()
 */
contract ERC1155Tradable is ERC1155MintBurn, ERC1155Metadata, Ownable, TokeniserRole {
	using SafeMath for uint256;

	uint256 private _currentTokenID = 0;
	mapping (uint256 => uint256) internal _tokenSupply;
	mapping (uint256 => uint256) private _tokenMaxSupply;
    // Contract name
	string public name;
	// Contract symbol
	string public symbol;
	
	constructor(
		string memory _name,
		string memory _symbol
	) {
		name = _name;
		symbol = _symbol;
	}
	
	function addTokeniser(address account) external onlyOwner {
		_addTokeniser(account);
	}

	function removeTokeniser(address account) external onlyOwner {
		_removeTokeniser(account);
    }

	/**
	 * @dev Returns the total amount for a token ID
	 * @param _id uint256 ID of the token to query
	 * @return amount of token in existence
	 */
	function tokenSupply(uint256 _id) external view returns (uint256) {
		return _tokenSupply[_id];
	}
	
	/**
	 * @dev Returns the maximum limit for a token ID
	 * @param _id uint256 ID of the token to query
	 * @return maximum amount of token that can be in existence
	 */
	function tokenMaxSupply(uint256 _id) external view returns (uint256) {
		return _tokenMaxSupply[_id];
	}	

    /**
     * @dev Will update the base URL of token's URI
     * @param _newBaseMetadataURI New base URL of token's URI
     */
    function setBaseMetadataURI(string memory _newBaseMetadataURI) external onlyOwner {
		_setBaseMetadataURI(_newBaseMetadataURI);
        string memory tokenURI;
        for (uint256 i = 1; i < _currentTokenID.add(1); i++) {
            tokenURI = string(abi.encodePacked(baseMetadataURI, _uint2str(i), ".json"));
            emit URI(tokenURI, i);
        }
	}

	/**
	 * @dev Creates a new token type and assigns _initialSupply to an address
	 * @param _maxSupply max supply allowed
	 * @param _initialSupply Optional amount to supply the first owner
	 * @param _data Optional data to pass if receiver is contract
	 * @return The newly created token ID
	 */
	function create(
		uint256 _maxSupply,
		uint256 _initialSupply,
		bytes calldata _data
	) external onlyTokeniser returns (uint256) {
		require(_initialSupply <= _maxSupply, "Initial supply cannot be more than max supply");
		uint256 _id = _getNextTokenID();
		_incrementTokenTypeId();
		
		string memory tokenURI = string(abi.encodePacked(baseMetadataURI, _uint2str(_id), ".json"));
		emit URI(tokenURI, _id);
		
		if (_initialSupply != 0) _mint(msg.sender, _id, _initialSupply, _data);
		_tokenSupply[_id] = _initialSupply;
		_tokenMaxSupply[_id] = _maxSupply;
		return _id;
	}

	/**
	 * @dev Mints some amount of tokens to an address
	 * @param _to          Address of the future owner of the token
	 * @param _id          Token ID to mint
	 * @param _amount      Amount of tokens to mint
	 * @param _data        Data to pass if receiver is contract
	 */
	function mint(
		address _to,
		uint256 _id,
		uint256 _amount,
		bytes memory _data
	) external onlyTokeniser {
		require(_tokenSupply[_id] + _amount <= _tokenMaxSupply[_id], "Mints exceeding Max Supply are forbidden");
		_mint(_to, _id, _amount, _data);
		_tokenSupply[_id] = _tokenSupply[_id].add(_amount);
	}

    /**
     * @dev Mint tokens for each id in _ids
     * @param _to          The address to mint tokens to
     * @param _ids         Array of ids to mint
     * @param _quantities  Array of amounts of tokens to mint per id
     * @param _data        Data to pass if receiver is contract
     */
    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) external onlyTokeniser {
      for (uint256 i = 0; i < _ids.length; i++) {
        uint256 _id = _ids[i];
        uint256 quantity = _quantities[i];
        require(_tokenSupply[_id] + quantity <= _tokenMaxSupply[_id], "Mints exceeding Max Supply are forbidden");
        _tokenSupply[_id] = _tokenSupply[_id].add(quantity);
      }
      _batchMint(_to, _ids, _quantities, _data);
    }

    /**
	 * @dev calculates the next token ID based on value of _currentTokenID
	 * @return uint256 for the next token ID
	 */
	function _getNextTokenID() private view returns (uint256) {
		return _currentTokenID.add(1);
	}

	/**
	 * @dev increments the value of _currentTokenID
	 */
	function _incrementTokenTypeId() private {
		_currentTokenID++;
	}
}

/**
 * @title Money Printer Goes Oof
 * @notice Additional burning and sending functions built on top of ERC1155Tradable plus combined ERC165 interface check, better serving the money printing needs of the Oofs.
 */
contract MoneyPrinterGoesOof is ERC1155Tradable {
	using SafeMath for uint256;
    
  /***********************************|
  |          ERC165 Functions         |
  |__________________________________*/

  /**
   * @notice Query if a contract implements an interface
   * @param _interfaceID  The interface identifier, as specified in ERC-165
   * @return `true` if the contract implements `_interfaceID` and
   */
   function supportsInterface(bytes4 _interfaceID) public override virtual pure returns (bool) {
    if (_interfaceID == type(IERC1155).interfaceId || _interfaceID == type(IERC1155TokenReceiver).interfaceId || _interfaceID == type(IERC1155Metadata).interfaceId) {
      return true;
    }
    return super.supportsInterface(_interfaceID);
   }
    
    /**
     * @notice Burn _amount of tokens of a given token id
     * @param _id      Token id to burn
     * @param _amount  The amount to be burned
     */	
	function burn(address _from, uint256 _id, uint256 _amount) external {
	    require((msg.sender == _from) || isApprovedForAll(_from, msg.sender), "MoneyPrinterGoesOof#burn: UNAPPROVED_OPERATOR");
	    _burn(_from, _id, _amount);
	    _tokenSupply[_id] = _tokenSupply[_id].sub(_amount);
	}
	
	/**
     * @notice Burn an array of tokens with specified amounts of each, i.e. burn _amounts[i] of each ids[i]
     * @param _ids      Array of token ids to burn
     * @param _quantities  Array of the amount to be burned
     */
	function batchBurn(address _from, uint256[] memory _ids, uint256[] memory _quantities) external {
	    require((msg.sender == _from) || isApprovedForAll(_from, msg.sender), "MoneyPrinterGoesOof#batchBurn: UNAPPROVED_OPERATOR");
	    for (uint256 i = 0; i < _ids.length; i++){
	        uint256 _id = _ids[i];
            uint256 quantity = _quantities[i];
            _tokenSupply[_id] = _tokenSupply[_id].sub(quantity);
	    }
	    _batchBurn(_from, _ids, _quantities);
	}
	
    /**
     * @notice Transfers _amount amount of an _id from the _from address to multiple _tos addresses
     * @param _from     Source address
     * @param _tos      Target addresses
     * @param _id       ID of the token type
     * @param _amount   Transfer amounts per token type
     * @param _data     Additional data with no specified format, sent in call to `_tos`
     */
    function safeTransferFrom_multipleReceipients(address _from, address[] memory _tos, uint256 _id, uint256 _amount, bytes memory _data) external {
	    for (uint256 i = 0; i < _tos.length; i++){
	        safeTransferFrom(_from, _tos[i], _id, _amount, _data);
	    }
	}

    constructor () ERC1155Tradable("Money Printer Goes Oof", "MPGoof"){}
}