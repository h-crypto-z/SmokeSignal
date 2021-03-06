pragma solidity 0.6.4;

// this doubles as a wrapper for the Maker medianizer contract
abstract contract EthPriceOracle
{
    function read()
        public 
        virtual
        view 
        returns(bytes32);
}

struct StoredMessageData 
{
    address firstAuthor;
    uint nativeBurned;
    uint dollarsBurned;
    uint nativeTipped;
    uint dollarsTipped;
}

contract SmokeSignal 
{
    address public donationAddress;
    EthPriceOracle public oracle;
    mapping (bytes32 => StoredMessageData) public storedMessageData;

    constructor(address _donationAddress, EthPriceOracle _oracle) 
        public 
    {
        donationAddress = _donationAddress;
        oracle = _oracle;
    }

    function EthPrice() 
        public
        view
        returns (uint _price)
    {
        return address(oracle) == address(0) ? 1 : uint(oracle.read());
    }

    event MessageBurn(
        bytes32 indexed _hash,
        address indexed _from,
        uint _burnAmount,
        string _message);

    function burnMessage(string calldata _message, uint _donateAmount)
        external
        payable
        returns(bytes32)
    {
        internalDonateIfNonzero(_donateAmount);

        bytes32 hash = keccak256(abi.encode(_message));

        uint burnAmount = msg.value - _donateAmount;
        uint burnValue = EthPrice() * burnAmount;
        internalBurnForMessageHash(hash, burnAmount, burnValue);

        if (storedMessageData[hash].firstAuthor == address(0))
        {
            storedMessageData[hash].firstAuthor = msg.sender;
        }

        emit MessageBurn(
            hash,
            msg.sender,
            burnValue,
            _message);

        return hash;
    }

    event HashBurn(
        bytes32 indexed _hash,
        address indexed _from,
        uint _burnAmount
    );

    function burnHash(bytes32 _hash, uint _donateAmount)
        external
        payable
    {        
        internalDonateIfNonzero(_donateAmount);

        uint burnAmount = msg.value - _donateAmount;
        uint burnValue = EthPrice() * burnAmount;
        internalBurnForMessageHash(_hash, burnAmount, burnValue);

        emit HashBurn(
            _hash,
            msg.sender,
            burnValue);
    }

    event HashTip(
        bytes32 indexed _hash,
        address indexed _from,
        uint _tipAmount);

    function tipHashOrBurnIfNoAuthor(bytes32 _hash, uint _donateAmount)
        external
        payable
    {
        uint burnAmount = msg.value - _donateAmount;
        uint burnValue = EthPrice() * burnAmount;
        internalDonateIfNonzero(_donateAmount);
        
        address author = storedMessageData[_hash].firstAuthor;
        if (author == address(0))
        {
            internalBurnForMessageHash(_hash, burnAmount, burnValue);

            emit HashBurn(
                _hash,
                msg.sender,
                burnValue);
        }
        else 
        {
            internalTipForMessageHash(_hash, author, burnAmount, burnValue);

            emit HashTip(
                _hash,
                msg.sender,
                burnValue);
        }
    }

    function internalBurnForMessageHash(bytes32 _hash, uint _burnAmount, uint _burnValue)
        internal
    {
        internalSend(address(0), _burnAmount);
        storedMessageData[_hash].nativeBurned += _burnAmount;
        storedMessageData[_hash].dollarsBurned += _burnValue;
    }

    function internalTipForMessageHash(bytes32 _hash, address author, uint _tipAmount, uint _tipValue)
        internal
    {
        internalSend(author, _tipAmount);
        storedMessageData[_hash].nativeTipped += _tipAmount;
        storedMessageData[_hash].dollarsTipped += _tipValue;
    }

    function internalDonateIfNonzero(uint _donateAmount)
        internal
    {
        if (_donateAmount > 0) 
        {
            internalSend(donationAddress, _donateAmount);
        }
    }

    function internalSend(address _to, uint _wei)
        internal
    {
        _to.call{ value: _wei }("");
    }
}

contract SmokeSignal_Ethereum is SmokeSignal
{
    constructor(address _donationAddress) SmokeSignal(_donationAddress, EthPriceOracle(0x729D19f657BD0614b4985Cf1D82531c67569197B))
        public 
    { }
}

contract SmokeSignal_xDai is SmokeSignal
{
    constructor(address _donationAddress) SmokeSignal(_donationAddress, EthPriceOracle(address(0)))
        public 
    { }
}