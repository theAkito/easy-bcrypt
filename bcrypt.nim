import pegs
#
#  bcrypt wrapper library
#
#  Written in 2011, 2013, 2014 by Ricardo Garcia <public@rg3.name>
#
#  To the extent possible under law, the author(s) have dedicated all copyright
#  and related and neighboring rights to this software to the public domain
#  worldwide. This software is distributed without any warranty.
#
#  You should have received a copy of the CC0 Public Domain Dedication along
#  with this software. If not, see
#  <http://creativecommons.org/publicdomain/zero/1.0/>.


##  Brief Example
##  -------------
##
##  Hashing a password:
##
##      hashPw(password, genSalt(12))
##
##  Verifying a password:
##
##      let savedHash = ...
##      if hashPw(password, savedHash) != savedHash:
##        echo "Password doesn't match"
##      else:
##        echo "Password matches!"
##
##
##  IMPORTANT NOTE: using strcmp or memcmp like in this simple example may make
##  your code vulnerable to timing attacks[1]. If possible, use a function that
##  always compares all the characters in the string before returning.
##
##  [1] https://en.wikipedia.org/wiki/Timing_attack

const
  BCRYPT_HASHSIZE = 64

{.compile: "lib/bcrypt.c"}
{.compile: "lib/crypt_blowfish/crypt_blowfish.c"}
{.compile: "lib/crypt_blowfish/x86.S"}
{.compile: "lib/crypt_blowfish/crypt_gensalt.c"}
{.compile: "lib/crypt_blowfish/wrapper.c"}

{.push importc, cdecl.}

#  This function expects a work factor between 4 and 31 and a char array to
#  store the resulting generated salt. The char array should typically have
#  BCRYPT_HASHSIZE bytes at least. If the provided work factor is not in the
#  previous range, it will default to 12.
#
#  The return value is zero if the salt could be correctly generated and
#  nonzero otherwise.
proc bcrypt_gensalt(workfactor: cint; salt: array[BCRYPT_HASHSIZE, char]): cint
#  This function expects a password to be hashed, a salt to hash the password
#  with and a char array to leave the result. It can also be used to verify a
#  hashed password. In that case, provide the expected hash in the salt
#  parameter and verify the output hash is the same as the input hash. Both the
#  salt and the hash parameters should have room for BCRYPT_HASHSIZE characters
#  at least.
#
#  The return value is zero if the password could be hashed and nonzero
#  otherwise.
proc bcrypt_hashpw(passwd: cstring; salt: array[BCRYPT_HASHSIZE, char];
                   hash: array[BCRYPT_HASHSIZE, char]): cint

{.pop.}


type
  PasswordSalt* = distinct array[BCRYPT_HASHSIZE, char]

proc genSalt*(workfactor: 4..32 = 10): PasswordSalt =
  if bcrypt_gensalt(cint workfactor, array[BCRYPT_HASHSIZE, char](result)) != 0:
    raise newException(Exception, "bcrypt salt generation failed")

proc hashPw*(password: cstring, salt: PasswordSalt): PasswordSalt =
  if bcrypt_hashpw(password, array[BCRYPT_HASHSIZE, char](salt),
                   array[BCRYPT_HASHSIZE, char](result)) != 0:
    raise newException(Exception, "bcrypt password hashing failed")

proc loadPasswordSalt*(val: string): PasswordSalt =
  var isValid = val.len > 7 and
                val[0] == '$' and
                val[1] == '2' and
                val[2] in {'a', 'y'} and
                val[3] == '$' and
                val[4] in {'0'..'9'} and  # max value is 32
                val[5] in {'0'..'9'} and
                val[6] == '$'
  if isValid:
    for i in 7 .. <val.len:
      if val[i] notin {'a'..'z', 'A'..'Z', '0'..'9', '/', '.'}:
        isValid = false

  if not isValid:
    raise newException(Exception, "Invalid password hash `" & val & "`")
  else:
    var resVal: array[BCRYPT_HASHSIZE, char]
    for i, v in val:
      resVal[i] = v
    return PasswordSalt(resVal)


proc `==`*(a, b: PasswordSalt): bool =
  var resultNum = 0
  for i in 0 .. <BCRYPT_HASHSIZE:
    resultNum = resultNum or (int8(array[BCRYPT_HASHSIZE, char](a)[i]) xor
                              int8(array[BCRYPT_HASHSIZE, char](b)[i]))

  return resultNum == 0

proc `$`*(self: PasswordSalt): string =
  result = ""
  for v in array[BCRYPT_HASHSIZE, char](self):
    result.add(v)