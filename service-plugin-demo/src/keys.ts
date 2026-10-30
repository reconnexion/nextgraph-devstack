// vim: expandtab
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { dirname } from 'path'
import { execFileSync } from 'child_process'
import { type KeyPair } from './types'

const ngcli = process.env.NGCLI ?? './ngcli'
const keyDir = process.env.KEY_DIR ?? '.'
const peerKeyFile = keyDir + '/peer.key'

function keyPairOfString(s: string): KeyPair {
  let js = JSON.parse(s)
  return { public: js.public, private: js.private }
}

// Return a fresh keypair, or throw
function generateKeyPair(): KeyPair {
  // `ngcli gen-key --json` outputs { "public":"...", "private":"..." }
  const stdout = execFileSync(ngcli, ['gen-key', '--json'],  { encoding: 'utf8' })
  return keyPairOfString(stdout)
}

// Return the saved peer keypair
function readKey(file: string): KeyPair | undefined {
  if (existsSync(file)) {
    return keyPairOfString(readFileSync(file, 'utf8'))
  }
}

function saveKey(file: string, kp: KeyPair): void {
  mkdirSync(dirname(file), { recursive: true })
  writeFileSync(file, JSON.stringify(kp), 'utf8')
}

// Return the peer keypair
export function peerKey(): KeyPair {
  let kp = readKey(peerKeyFile)
  if (kp === undefined) {
    console.debug('Creating a new key-pair for my peer-id')
    kp = generateKeyPair()
    saveKey(peerKeyFile, kp)
  }
  return kp
}
