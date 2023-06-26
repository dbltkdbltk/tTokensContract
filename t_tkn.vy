event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    sndr_contract: address
    rcvr_contract: address
    t_token: indexed(bytes32)
    
event MinterSet:
    actor: address
    pre_minter: address
    approver: address
    minter: address

interface OtherContract:
    def interContract(_to: address, _sender: address, _token: bytes32) -> bool: nonpayable
    
users: public(HashMap[address, bool])

t_tokens: public(HashMap[bytes32, address])

t_contracts: public(HashMap[address, bool])

minter: address

admins: address[2]

pre_minter: address

approver: address
    
@external
def __init__(_admin0: address, _admin1: address):
    assert _admin0 != _admin1
    self.admins = [_admin0, _admin1]

@internal
def _transfer(_to: address, _sender: address, _contract: address, _token: bytes32):
    assert self.t_tokens[_token] == _sender
    if _contract == self:
        assert self.users[_to] == True
        self.t_tokens[_token] = _to
    else:
        assert self.t_contracts[_contract] == True
        self.t_tokens[_token] = ZERO_ADDRESS
        OtherContract(_contract).interContract(_to, _sender, _token)
    log Transfer(_sender, _to, self, _contract, _token)

@external
def interContract(_to: address, _sender: address, _token: bytes32) -> bool:
    assert self.t_contracts[msg.sender] == True
    assert self.users[_to] == True
    assert self.t_tokens[_token] == ZERO_ADDRESS
    self.t_tokens[_token] = _to
    log Transfer(_sender, _to, msg.sender, self, _token)
    return True

@external
def transfer(_to: address, _contract: address, _token: bytes32):
    self._transfer(_to, msg.sender, _contract, _token)
    
@external
def transferFor(_to: address, _contract: address, _token: bytes32, _v: uint256, _r: uint256, _s: uint256):
    _from: address = ecrecover(keccak256(concat(convert(_to, bytes32), _token)), _v, _r, _s)
    assert _from != ZERO_ADDRESS
    self._transfer(_to, _from, _contract, _token)
    
@external
def mint(_to: address, _token: bytes32):
    assert self.minter == msg.sender
    assert self.users[_to] == True
    assert self.t_tokens[_token] == ZERO_ADDRESS
    self.t_tokens[_token] = _to
    log Transfer(ZERO_ADDRESS, _to, self, self, _token)
    
@external
def burn(_token: bytes32):
    assert self.minter == msg.sender
    assert self.t_tokens[_token] != ZERO_ADDRESS
    _owner: address = self.t_tokens[_token]
    self.t_tokens[_token] = ZERO_ADDRESS
    log Transfer(_owner, ZERO_ADDRESS, self, self, _token)  
    
@external
def userOn(_user: address):
    assert self.users[_user] != True
    assert self.minter == msg.sender
    self.users[_user] = True
    
@external
def userOff(_user: address):
    assert self.users[_user] == True
    assert msg.sender == self.minter or msg.sender == _user
    self.users[_user] = False

@external
def userOffFrom(_v: uint256, _r: uint256, _s: uint256):
    _user: address = ecrecover(keccak256('kill me'), _v, _r, _s)
    assert _user != ZERO_ADDRESS
    assert self.users[_user] == True
    self.users[_user] = False
    
@external
def otherContractOn(_contract: address):
    assert self.t_contracts[_contract] != True
    assert self.minter == msg.sender
    self.t_contracts[_contract] = True
    
@external
def otherContractOff(_contract: address):
    assert self.t_contracts[_contract] == True
    assert self.minter == msg.sender
    self.t_contracts[_contract] = False
    
@external
def minterSet(_minter: address):
    if self.pre_minter == ZERO_ADDRESS and self.approver == ZERO_ADDRESS:
        assert self.admins[0] == msg.sender or self.admins[1]  == msg.sender
        for i in self.admins:
            if i == msg.sender:
                pass
            else:
                self.approver = i
        self.pre_minter = _minter
        log MinterSet(msg.sender, self.pre_minter, self.approver, self.minter)
    else:
        assert self.approver == msg.sender
        assert self.pre_minter == _minter
        self.minter = self.pre_minter
        self.pre_minter = ZERO_ADDRESS
        self.approver = ZERO_ADDRESS
        log MinterSet(msg.sender, self.pre_minter, self.approver, self.minter)
