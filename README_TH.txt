BY TRXP — LOCAL WEB DASHBOARD v2.7
================================

เปิดหน้า Dashboard ใน Microsoft Edge / Google Chrome แล้วสั่งงาน Windows บนเครื่องนี้ผ่าน local-only connector (127.0.0.1)

วิธีเปิดใช้งาน
1. แตก ZIP ทั้งหมดลงในโฟลเดอร์ถาวร เช่น C:\BY-TRXP\ (อย่าเปิดไฟล์จากภายใน ZIP)
2. ดับเบิลคลิก Open-Dashboard.bat หรือคลิกขวาแล้ว Run as administrator
3. กด Yes ที่หน้าต่าง UAC เพราะฟังก์ชัน Driver REG และ Power Plan ต้องใช้สิทธิ์ Administrator
4. หน้า BY TRXP จะเปิดใน Edge/Chrome อัตโนมัติ
5. เมื่อใช้งานเสร็จ กด “ปิด Dashboard” ในหน้าเว็บ หรือปิดหน้าต่าง PowerShell ที่เปิดตัวเชื่อม

ฟังก์ชัน
- PC Specs: แสดง Windows/build, CPU/core/thread, RAM รวม/ว่าง, GPU, เมนบอร์ด, รายชื่อดิสก์/ขนาด และ Network Adapter/Link speed แบบอ่านอย่างเดียว ไม่แสดง serial number หรือชื่อบัญชีผู้ใช้. กดรีเฟรชสถานะเพื่ออัปเดต.
- SETTING TRXP — Mouse/Keyboard Driver REG: นำเข้า MouseDataQ.reg และ KeyboardDataQ.reg หลังสำรองค่า Registry ที่จะเปลี่ยน
- Mouse FAST / Keyboard: เปลี่ยนค่าผู้ใช้ เช่นปิด mouse acceleration และ DoubleClick 200 ms โดยสำรองค่าเดิม
- Network: ปรับ Receive/Transmit Buffers และพยายามใช้ RX/TX Interrupt Moderation, Flow Control, Wake on Magic Packet/Pattern เฉพาะค่าและคุณสมบัติที่ไดรเวอร์แสดงว่ารองรับ โดยสำรองค่าที่พบทั้งหมดก่อนแก้ มี Restore Network Adapter และ Flush DNS; การปิด Interrupt Moderation อาจเพิ่มภาระ CPU และการปรับ/คืนค่าอาจทำให้อินเทอร์เน็ตหลุดชั่วคราว ไม่รับประกัน Ping/FPS.
- TRXP Power Plan: สร้างสำเนาจาก Balanced ชื่อ TRXP และเก็บ GUID แผนเดิม
- RAMMap: เปิด RAMMap และสั่งล้าง Standby List
- Cleaner: ล้างรายการใน Windows/User Temp; ข้ามไฟล์ที่ใช้งานหรือไม่มีสิทธิ์
- FIVEM (หัวข้อแยก): ปุ่ม Apply TRXP FIVEM INI Profile เขียนค่าที่กำหนดลง CitizenFX.ini พร้อมสำรองไฟล์เดิมอัตโนมัติ, เปิดไฟล์ใน Notepad และล้าง FiveM Cache (ไม่มีปุ่มคืนค่า CitizenFX.ini)
- Restore: คืนค่า Mouse/Keyboard, Network Adapter และ Power Plan จากไฟล์สำรองที่ BY TRXP สร้างไว้เท่านั้น

ความปลอดภัยและข้อควรทราบ
- Dashboard ผูก listener กับ 127.0.0.1 เท่านั้น ไม่เปิดให้เครื่องอื่นเข้าถึง และไม่มี analytics/remote API
- อย่าเผยแพร่โฟลเดอร์นี้พร้อมไฟล์ backup เพราะมีข้อมูลค่าระบบเดิมของเครื่อง
- KeyboardDataQ.reg มี ThreadPriority=31 ซึ่งสูงมากและอาจกระทบเสถียรภาพ ไม่รับประกันว่าลด input lag/FPS; ควรหลีกเลี่ยงหากไม่จำเป็น
- ล้าง Standby List ไม่ได้เพิ่ม RAM จริงและอาจทำให้โหลดซ้ำช้าชั่วคราว
- ปิด FiveM ก่อนล้าง FiveM cache
- การล้าง Temp อาจข้ามไฟล์ที่ใช้งานอยู่
- Restore จะใช้ได้เฉพาะหลังจากฟังก์ชันนั้นสร้างไฟล์ backup แล้ว ห้ามลบไฟล์ BY_TRXP_Web_*_Backup.json ก่อนคืนค่า
- ถ้าต้องการสร้าง EXE ให้รัน Build-EXE.bat บน Windows 10/11 ที่เชื่อมต่ออินเทอร์เน็ต ตัว build จะติดตั้ง PS2EXE จาก PowerShell Gallery และสร้าง BY_TRXP_WebDashboard.exe; ไม่ได้รวม EXE ที่คอมไพล์แล้วใน ZIP นี้

ไฟล์ที่ต้องอยู่ในโฟลเดอร์เดียวกัน
- dashboard.html, Start-BY-TRXP-WebDashboard.ps1
- assets\BY_TRXP_Background.png และ BY_TRXP_Banner.png
- MouseDataQ.reg, KeyboardDataQ.reg
- RAMMap.exe, RAMMap64.exe, RAMMap64a.exe, Eula.txt
- FilterKeysSetter.exe

RAMMap © Microsoft Sysinternals. โปรดอ่าน Eula.txt ที่รวมมาในแพ็กเกจ.


แก้ไข v2.2: API จะส่ง JSON สำหรับข้อผิดพลาดภายใน, หน้าเว็บจะแสดง HTTP status/content type และตัวอย่าง response เพื่อช่วยวินิจฉัย; Network รองรับการสำรอง/คืนค่าของ keyword เพิ่มตามไดรเวอร์จริง.


SETTING TRXP — Network Latency (เพิ่มเติม)
- ใช้ปุ่ม Apply Setting TRXP Network เพื่อปิด Interrupt Moderation / Energy Efficient / Flow Control เฉพาะค่าที่ไดรเวอร์รองรับ และตั้งค่า netsh TCP/IP ตามที่ผู้ใช้ให้มา
- ก่อนเปลี่ยนจะสร้าง BY_TRXP_Web_SettingTRXP_Backup.json และ export TCP/IP registry branches เป็น .reg
- ใช้ Restore Setting TRXP เพื่อนำเข้าข้อมูลสำรองกลับ การนำเข้า TCP/IP registry อาจแทนที่การเปลี่ยนแปลง TCP/IP อื่น ๆ ที่เกิดหลังสำรอง จึงควร Restore ก่อนปรับ TCP/IP ด้วยโปรแกรมอื่น
- netdma/chimney/taskoffload เป็นตัวเลือกเก่าหรืออาจไม่รองรับใน Windows บางรุ่น; โปรแกรมจะแสดงคำสั่งที่ไม่สำเร็จ ไม่รับประกันว่าจะลด ping/FPS


แก้ไข v2.3: แก้ PowerShell Argument types do not match ที่เกิดจากการใช้ array-subexpression กับ Generic List[object] โดยใช้ .ToArray() และเปลี่ยนชุดคำสั่ง netsh เป็นรายการ object ที่เก็บ string[] แยกคำสั่ง เพื่อป้องกันอาร์กิวเมนต์แบน/ชนิดผิด. เพิ่ม PC Specs แบบ read-only ใน Dashboard และเพิ่ม stack trace ลงไฟล์ log เมื่อมีคำสั่งผิดพลาด.


อัปเดต v2.4 — PC SPECS VISUAL REDESIGN
- จัดหน้า PC Specs ใหม่เป็น System Profile แบบ gaming dashboard พร้อม accent สี cyan/blue, hardware cards, indicator และ layout ปรับตามขนาดหน้าจอ
- ไฮไลต์ CPU, Windows, RAM พร้อมแถบ RAM usage ที่คำนวณจาก total/available ที่ Windows รายงาน
- เพิ่มการ์ด GPU, Motherboard, Storage และ Active Network ให้ดูแยกหมวดชัดเจน
- ไม่มีข้อมูลสเปคตัวอย่างถูกฝังไว้ในหน้าใช้งานจริง; จะแสดงข้อมูลจากเครื่องเมื่อ local service ตอบกลับเท่านั้น.


อัปเดต v2.5 — เพิ่มหมวด FIVEM แยกเป็นหัวข้อใหญ่
- เพิ่มปุ่ม Apply FiveM Supported INI Settings, Restore CitizenFX.ini เดิม และเปิดไฟล์ใน Notepad
- ก่อนเขียนจะเก็บเนื้อหา CitizenFX.ini เดิมแบบไบต์ต่อไบต์ลง BY_TRXP_Web_CitizenFX_Backup.json; Restore ใช้สำเนานี้คืนไฟล์เดิม หรือเอาไฟล์ที่สร้างใหม่ออก หากก่อนหน้าจะยังไม่มีไฟล์
- เปลี่ยนเฉพาะคีย์ใน [Game] ที่เอกสาร FiveM ระบุ: UpdateChannel=production, DisableNVSP=0, DisableCrashUpload=1, DisableOSVersionCheck=0, EnableFullMemoryDump=0
- คีย์ custom [Renderer], [System], [GameTweaks], [Network], [Input], [Streaming] ที่ผู้ใช้ส่งมาไม่ได้เขียนลง CitizenFX.ini เพราะไม่ได้อยู่ในตัวเลือกที่เอกสาร CitizenFX.ini ระบุรองรับ; การเพิ่มชื่อคีย์ดังกล่าวไม่แปลว่า FiveM จะนำไปใช้
- คำเตือน: DisableNVSP=0 อนุญาตให้ NVIDIA overlay ทำงานได้ และเอกสาร FiveM ระบุว่า overlay อาจทำให้เกิด crash; ไม่รับประกัน FPS/Ping
- FiveM Cache ย้ายเข้าไปอยู่ภายใต้หมวดใหญ่ FIVEM; Cleaner เหลือเฉพาะ Windows Temp


อัปเดต v2.6 — TRXP FIVEM INI PROFILE
- ปุ่ม Apply TRXP FIVEM INI Profile เขียน [Game], [Renderer], [System], [GameTweaks], [Network], [Input], [Streaming] และค่าที่ผู้ใช้ระบุลง CitizenFX.ini จริง
- ไม่มีปุ่ม Restore CitizenFX.ini ในหน้า Dashboard ตามคำขอ
- ก่อนเขียนจะคัดลอกไฟล์เดิมเป็น CitizenFX.ini.BYTRXP-backup-วันที่เวลา ในโฟลเดอร์ FiveM.app เพื่อเก็บต้นฉบับแยกไว้
- คำเตือน: เอกสารทางการ FiveM ระบุรองรับเพียงบางคีย์ใน [Game]; คีย์ custom อาจถูกละเลย ไม่รับประกันว่าจะมีผลกับเกมหรือเพิ่ม FPS/ลด Ping


อัปเดต v2.7 — FIX CitizenFX.ini Apply
- แก้บั๊ก PowerShell ที่ใช้ชื่อตัวแปร $matches ชนกับตัวแปรพิเศษ $Matches ทำให้เกิด Cannot find an overload for Add และหยุดก่อนเขียนค่า
- เปลี่ยนเป็น $matchingLineIndexes เพื่อให้เขียน/อัปเดตคีย์ INI ที่มีอยู่แล้วได้
- ยังคงสำรอง CitizenFX.ini เดิมอัตโนมัติ และไม่มีปุ่มคืนค่าใน Dashboard
