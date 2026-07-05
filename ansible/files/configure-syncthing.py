#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import argparse
import sys
import os

def main():
    parser = argparse.ArgumentParser(description="Configure Syncthing device and folder pairings in config.xml")
    parser.add_argument('--config', help="Path to config.xml")
    parser.add_argument('--nas-device-id', help="Device ID of the remote NAS")
    parser.add_argument('--folder-id', help="Folder ID of the sync folder")
    parser.add_argument('--local-path', help="Local directory path for syncing")
    parser.add_argument('--local-device-id', help="Local Syncthing device ID")
    parser.add_argument('--nas-address', help="Explicit address of the remote NAS (e.g. tcp://10.0.0.10:22000)")
    parser.add_argument('--validate', action='store_true', help="Only validate inputs and exit")
    args = parser.parse_args()

    # Early validation of inputs
    errors = []
    if not args.nas_device_id or args.nas_device_id.strip() == "":
        errors.append("Missing or empty 'syncthing_nas_device_id'")
    if not args.nas_address or args.nas_address.strip() == "":
        errors.append("Missing or empty 'syncthing_nas_address'")
    if not args.folder_id or args.folder_id.strip() == "":
        errors.append("Missing or empty 'syncthing_folder_id'")
    if not args.local_path or args.local_path.strip() == "":
        errors.append("Missing or empty 'syncthing_local_path'")

    if not args.validate:
        if not args.config or args.config.strip() == "":
            errors.append("Missing --config argument")
        if not args.local_device_id or args.local_device_id.strip() == "":
            errors.append("Missing --local-device-id argument")

    if errors:
        print("\n[ERROR] Syncthing configuration failed validation:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        print("\nPlease update your 'ansible/vars/secrets.yml' file to proceed.", file=sys.stderr)
        sys.exit(1)

    if args.validate:
        print("Validation successful.")
        sys.exit(0)


    if not os.path.exists(args.config):
        print(f"Error: Config file not found at {args.config}", file=sys.stderr)
        sys.exit(1)

    try:
        tree = ET.parse(args.config)
        root = tree.getroot()
    except Exception as e:
        print(f"Error parsing XML: {e}", file=sys.stderr)
        sys.exit(1)

    changed = False

    # 1. Ensure the NAS device is added to the configuration root
    nas_device = None
    for device in root.findall('device'):
        if device.get('id') == args.nas_device_id:
            nas_device = device
            break

    if nas_device is None:
        # Create a new device element
        nas_device = ET.SubElement(root, 'device', {
            'id': args.nas_device_id,
            'name': 'NAS',
            'compression': 'metadata',
            'introducer': 'false',
            'skipIntroductionRemovals': 'false',
            'introducedBy': ''
        })
        changed = True

    # Configure the device address
    existing_addresses = nas_device.findall('address')
    target_address = args.nas_address if args.nas_address else 'dynamic'
    
    if len(existing_addresses) != 1 or existing_addresses[0].text != target_address:
        for addr in list(existing_addresses):
            nas_device.remove(addr)
        addr_elem = ET.SubElement(nas_device, 'address')
        addr_elem.text = target_address
        changed = True

    # 2. Ensure the sync folder is configured
    folder = None
    for f in root.findall('folder'):
        if f.get('id') == args.folder_id:
            folder = f
            break

    if folder is None:
        # Create a new folder element
        folder = ET.SubElement(root, 'folder', {
            'id': args.folder_id,
            'label': args.folder_id,
            'path': args.local_path,
            'type': 'sendreceive',
            'rescanIntervalS': '3600',
            'ignorePerms': 'false',
            'autoNormalize': 'true'
        })
        changed = True
    else:
        # Verify and update folder path if it changed
        expanded_local_path = os.path.abspath(os.path.expanduser(args.local_path))
        existing_path = os.path.abspath(os.path.expanduser(folder.get('path', '')))
        if existing_path != expanded_local_path:
            folder.set('path', args.local_path)
            changed = True

    # 3. Ensure both local and NAS devices are associated with the folder
    folder_devices = {d.get('id') for d in folder.findall('device')}

    for device_id in [args.local_device_id, args.nas_device_id]:
        if device_id not in folder_devices:
            ET.SubElement(folder, 'device', {
                'id': device_id,
                'introducedBy': ''
            })
            changed = True

    if changed:
        try:
            # Reformat XML indentation nicely (Python 3.9+)
            ET.indent(tree, space="    ", level=0)
            tree.write(args.config, encoding="utf-8", xml_declaration=True)
            print("CHANGED")
        except Exception as e:
            print(f"Error writing XML: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print("NO_CHANGE")

if __name__ == '__main__':
    main()
