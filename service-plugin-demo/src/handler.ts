import { type PluginStatus, assertIsPluginStatus } from './types'

type Response = any // TODO

let currentStatus: PluginStatus = "Waiting"

export function updateStatus(status: PluginStatus) {
  if (currentStatus != status) {
    console.info('New status: ', status)
    currentStatus = status
  }
}

// Requests from users ({User: id}) or other plugins ({Plugin: name}):
export function requestHandler(caller: any, serviceName: string, request: any): Response {
  console.log('requestHandler: got request=', request, 'for', serviceName, 'from', caller)
  // TODO
  return { ok: true, data: 42 }
}

// Notifications from the broker, such as {StatusChange: "Enabled"}:
export function notifyHandler(serviceName: string, notification: any): void {
  console.log('notifyHandler: got notification=', notification, 'for', serviceName)
  if ('StatusChange' in notification) {
    assertIsPluginStatus(notification.StatusChange)
    updateStatus(notification.StatusChange)
  }
}
