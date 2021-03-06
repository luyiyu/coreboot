/*
 * This file is part of the coreboot project.
 *
 * Copyright 2019 Google LLC
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of
 * the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

/*
 * The Realtek r8152 driver in the Linux kernel supports a MAC address
 * passthru feature which can result in the dock ethernet port using the
 * same MAC address that is assigned to the internal NIC.  This is done
 * by calling an ACPI method at \_SB.AMAC() which returns a formatted
 * string (as a buffer) containing the MAC address for the dock to use.
 *
 * The Linux kernel implementation can be found at
 * drivers/net/usb/r8152.c:vendor_mac_passthru_addr_read()
 *
 * For Chrome OS, the policy which controls where the dock MAC address
 * comes from is written into RW_VPD property "dock_passthru":
 *
 *   "dock_mac" or empty: Use MAC address from RO_VPD value "dock_mac"
 *   "ethernet_mac0": Use MAC address from RO_VPD value "ethernet_mac0"
 *   "builtin": existing dock MAC address (return nothing)
 */

Scope (\_SB)
{
	Method (AMAC, 0, Serialized)
	{
		/* Format expected by the Linux kernel r8152 driver */
		Name (MACA, "_AUXMAC_#XXXXXXXXXXXX#")

		/* Get "dock_passthru" value from RW_VPD */
		Local0 = \VPD.VPDF ("RW", "dock_passthru")

		Switch (ToString (Local0))
		{
			Case ("ethernet_mac0") {
				Local1 = \VPD.VPDF ("RO", "ethernet_mac0")
			}
			Case ("builtin") {
				Return (Zero)
			}
			/* "dock_mac" or policy not found. */
			Default {
				Local1 = \VPD.VPDF ("RO", "dock_mac")
			}
		}
		If (!Local1) {
			Return (Zero)
		}
		Printf ("MAC address returned from VPD: %o", Local1)

		/* Verify MAC address format is AA:BB:CC:DD:EE:FF */
		For (Local3 = 2, Local3 < 17, Local3 += 3) {
			If (ToString (DerefOf (Local1[Local3])) != ":") {
				Printf ("Invalid MAC address byte %o", Local3)
				Return (Zero)
			}
		}

		/* Convert MAC address into format specified by MACA */
		Local2 = ToBuffer (MACA)
		Local4 = 0 /* First MAC address byte in input buffer */
		Local5 = 9 /* First MAC address byte in output buffer */
		For (Local3 = 0, Local3 < 6, Local3++) {
			Local2[Local5] = DerefOf (Local1[Local4])
			Local2[Local5 + 1] = DerefOf (Local1[Local4 + 1])
			Local5 += 2
			Local4 += 3 /* Skip ":" in address from VPD */
		}

		Printf ("AMAC = %o", ToString (Local2))
		Return (Local2)
	}
}
