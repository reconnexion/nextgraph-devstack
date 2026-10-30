import { type PluginStatus, assertIsPluginStatus } from './types'

type Response = any // TODO

let currentStatus: PluginStatus = "Waiting"

function updateStatus(status: PluginStatus) {
  if (currentStatus != status) {
    console.info('New status: ', status)
    currentStatus = status
  }
}

export function msgHandler(msg: any, sender: any): Response {
  console.log('msgHandler: got msg=', msg, ' and sender=', sender)
  switch (sender) {
    case "Broker":
      /* We have a new status */
      assertIsPluginStatus(msg)
      updateStatus(msg)
      return { ok: true }
    default:
      // TODO
      return { ok: true, data: 42 }
  }
}
