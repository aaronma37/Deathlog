--[[
Copyright 2023 Yazpad
The Deathlog AddOn is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Hardcore.

The Deathlog AddOn is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The Deathlog AddOn is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the Deathlog AddOn. If not, see <http://www.gnu.org/licenses/>.
--]]
--
local overlay_info = {
	[1411] = {
		["128:110:464:33"] = "271427",
		["160:120:413:476"] = "2212659",
		["160:190:474:384"] = "271426",
		["190:180:462:286"] = "271440",
		["190:200:327:60"] = "271439",
		["200:240:549:427"] = "271437",
		["210:160:427:78"] = "271428",
		["215:215:355:320"] = "271443",
		["220:230:432:170"] = "271421",
		["230:230:301:189"] = "271422",
		["445:160:244:0"] = "271435, 271442",
	},
	[1412] = {
		["128:120:473:260"] = "272185",
		["128:155:379:242"] = "272178",
		["128:205:303:307"] = "272176",
		["170:128:458:369"] = "272180",
		["185:128:291:0"] = "272172",
		["205:128:395:0"] = "272179",
		["205:230:502:16"] = "272169",
		["210:180:255:214"] = "272181",
		["215:240:428:80"] = "272177",
		["225:235:532:238"] = "272186",
		["256:190:523:356"] = "272170",
		["256:200:367:303"] = "272173",
		["280:240:249:59"] = "272187, 272171",
		["470:243:270:425"] = "272168, 272165",
	},
	[1413] = {
		["100:165:564:52"] = "270569",
		["115:110:507:294"] = "852702",
		["120:110:555:0"] = "270553",
		["120:125:384:115"] = "270560",
		["125:115:492:63"] = "270584",
		["125:125:556:189"] = "270585",
		["125:165:442:298"] = "852696",
		["128:100:412:0"] = "852705",
		["128:105:419:63"] = "270554",
		["128:128:306:130"] = "852699",
		["128:128:341:537"] = "852704",
		["128:128:431:479"] = "852694",
		["140:128:498:119"] = "270574",
		["145:125:365:350"] = "852697",
		["150:120:527:307"] = "852701",
		["155:115:407:553"] = "852703",
		["155:128:335:462"] = "852695",
		["155:128:481:211"] = "270565",
		["155:155:431:118"] = "270559",
		["170:120:456:0"] = "270564",
		["175:185:365:177"] = "852700",
		["200:145:317:29"] = "270572",
		["200:185:340:234"] = "852693",
		["210:150:355:402"] = "852698",
		["95:100:581:247"] = "270573",
	},

	[1416] = {
		["160:175:225:478"] = "768731",
		["165:197:314:471"] = "768752",
		["190:170:317:372"] = "768732",
		["195:288:399:380"] = "768721, 768722",
		["200:200:406:279"] = "768730",
		["220:280:196:131"] = "768738, 769205",
		["235:200:462:77"] = "768753",
		["255:255:270:197"] = "768739",
		["255:320:462:307"] = "768744, 768745",
		["280:240:334:162"] = "768723, 769200",
		["285:230:276:0"] = "768728, 768729",
		["300:300:26:262"] = "769201, 769202, 769203, 769204",
		["330:265:44:403"] = "768734, 768735, 768736, 768737",
		["350:370:626:253"] = "768717, 768718, 768719, 768720",
		["370:300:549:105"] = "768748, 768749, 768750, 768751",
	},
	[1417] = {
		["160:230:558:112"] = "270360",
		["170:155:419:293"] = "2212546",
		["175:225:370:186"] = "270352",
		["180:210:472:165"] = "270350",
		["190:210:138:54"] = "270347",
		["190:240:87:138"] = "2212539",
		["200:220:355:412"] = "270348",
		["205:250:655:120"] = "270336",
		["210:185:286:310"] = "270346",
		["215:210:559:333"] = "270353",
		["215:235:432:362"] = "270342",
		["230:195:531:276"] = "270343",
		["230:240:192:90"] = "270351",
		["240:230:108:287"] = "270358",
		["245:245:232:145"] = "270349",
		["256:215:171:424"] = "270361",
	},
	[1418] = {
		["195:200:325:148"] = "270543",
		["200:195:445:120"] = "270532",
		["220:220:551:48"] = "270530",
		["230:230:349:256"] = "2212608",
		["240:255:0:148"] = "2212593",
		["245:205:389:7"] = "2212606",
		["245:205:498:209"] = "2212592",
		["255:205:17:310"] = "270529",
		["255:220:12:428"] = "270520",
		["255:280:501:341"] = "270540, 270527",
		["265:270:345:389"] = "270522, 270550, 270528, 270536",
		["270:275:159:199"] = "270525, 270521, 2212603, 2212605",
		["285:240:148:384"] = "2212599, 2212601",
		["370:455:611:110"] = "270534, 270551, 270546, 270535",
	},
	[1419] = {
		["170:145:405:123"] = "391431",
		["170:200:472:9"] = "391433",
		["185:155:310:133"] = "391425",
		["185:190:559:30"] = "391432",
		["195:180:361:15"] = "391435",
		["225:170:501:140"] = "391430",
		["245:195:361:195"] = "391434",
		["265:220:453:259"] = "391437, 391436",
		["384:450:212:178"] = "391429, 391428, 391427, 391426",
	},
	[1420] = {
		["128:158:537:299"] = "273015",
		["150:128:474:327"] = "273016",
		["173:128:694:289"] = "273000",
		["174:220:497:145"] = "273020",
		["175:247:689:104"] = "272996",
		["186:128:395:277"] = "2213434",
		["201:288:587:139"] = "273009, 273002",
		["211:189:746:125"] = "2213425",
		["216:179:630:326"] = "273006",
		["230:205:698:362"] = "2213418",
		["237:214:757:205"] = "272999",
		["243:199:363:349"] = "273003",
		["245:205:227:328"] = "273001",
		["256:156:239:250"] = "273017",
		["256:210:335:139"] = "273019",
		["315:235:463:361"] = "2213428, 2213430",
	},
	[1421] = {
		["140:125:391:446"] = "2213067",
		["160:170:470:261"] = "272598",
		["165:185:382:252"] = "272616",
		["175:165:402:65"] = "2213080",
		["180:128:323:128"] = "2213065",
		["180:185:457:144"] = "2213082",
		["185:165:286:37"] = "272610",
		["210:160:352:168"] = "272620",
		["210:215:379:447"] = "272609",
		["220:160:364:359"] = "272613",
		["240:180:491:417"] = "272599",
		["240:240:494:262"] = "272614",
		["250:215:593:74"] = "272600",
		["256:160:465:0"] = "2213063",
		["256:220:459:13"] = "2213084",
	},
	[1422] = {
		["160:125:300:311"] = "273113",
		["160:200:566:198"] = "273121",
		["170:165:600:412"] = "273107",
		["170:190:451:323"] = "273102",
		["180:205:520:250"] = "273094",
		["205:340:590:86"] = "273122, 273103",
		["220:150:381:265"] = "2212523",
		["220:180:382:164"] = "273114",
		["225:185:137:293"] = "273120",
		["285:230:260:355"] = "2212522, 2212521",
		["300:206:355:462"] = "273108, 273101",
		["340:288:307:16"] = "273095, 273111, 273100, 273090",
		["370:270:504:343"] = "273119, 273092, 273112, 273093",
	},
	[1423] = {
		["165:160:537:367"] = "271544",
		["175:245:716:299"] = "271533",
		["180:160:592:241"] = "271542",
		["185:150:172:477"] = "271512",
		["190:205:620:128"] = "271520",
		["190:205:79:98"] = "271522",
		["195:275:620:291"] = "271543, 271530",
		["200:205:156:360"] = "271551",
		["205:165:291:401"] = "271548",
		["205:165:614:30"] = "271554",
		["205:250:409:345"] = "2212700",
		["210:179:309:489"] = "271514",
		["210:210:271:261"] = "271536",
		["220:360:7:231"] = "2212705, 2212706",
		["225:215:722:166"] = "271537",
		["230:150:422:36"] = "271535",
		["230:235:442:199"] = "271523",
		["240:195:457:109"] = "271521",
		["240:200:194:9"] = "271529",
		["245:170:717:471"] = "271553",
		["250:175:537:463"] = "271532",
		["360:270:169:83"] = "271518, 271527, 2212703, 2212704",
	},
	[1424] = {
		["125:100:109:482"] = "271904",
		["165:200:175:275"] = "2212736",
		["205:155:414:154"] = "271897",
		["215:240:541:236"] = "2212742",
		["220:310:509:0"] = "271894, 2212744",
		["230:320:524:339"] = "2212737, 2212738",
		["235:270:418:201"] = "271905, 2212743",
		["240:275:637:294"] = "271885, 271877",
		["285:155:208:368"] = "2212746, 2212747",
		["288:225:2:192"] = "271876, 271881",
		["305:275:198:155"] = "271883, 271892, 2212739, 2212740",
		["384:365:605:75"] = "271872, 271898, 271882, 271891",
	},
	[1425] = {
		["145:220:158:149"] = "271927",
		["160:145:512:232"] = "271933",
		["170:170:319:302"] = "271934",
		["170:310:693:303"] = "271938, 271916",
		["180:170:408:260"] = "271929",
		["185:195:237:185"] = "271928",
		["195:185:240:387"] = "271937",
		["200:165:373:365"] = "271922",
		["205:195:374:164"] = "271910",
		["225:200:171:306"] = "770218",
		["235:285:505:333"] = "271912, 271920",
		["255:205:13:245"] = "271917",
		["275:275:509:19"] = "271908, 271935, 271936, 271909",
		["280:205:571:239"] = "271915, 271921",
	},
	[1426] = {
		["115:115:252:249"] = "2212640",
		["125:125:217:287"] = "271398",
		["128:120:792:279"] = "2212654",
		["128:128:573:280"] = "271389",
		["128:165:502:221"] = "2212651",
		["128:165:759:173"] = "2212653",
		["128:180:281:167"] = "271392",
		["128:190:347:163"] = "271418",
		["150:128:295:385"] = "271406",
		["155:128:522:322"] = "271401",
		["155:170:694:273"] = "271409",
		["165:165:608:291"] = "271408",
		["180:128:274:296"] = "2212641",
		["180:165:166:184"] = "2212644",
		["200:185:314:311"] = "271400",
		["200:200:386:294"] = "271417",
		["240:185:155:403"] = "2212639",
		["315:200:397:163"] = "271410, 271396",
	},
	[1427] = {
		["275:235:77:366"] = "254503, 254504",
		["305:220:494:300"] = "2201968, 2201949",
		["305:230:545:407"] = "254527, 254528",
		["360:280:247:388"] = "2201972, 2201970, 2201969, 2201971",
		["405:430:85:30"] = "254509, 254510, 254511, 254512",
		["425:325:250:170"] = "254529, 254530, 254531, 254532",
		["460:365:422:8"] = "254505, 254506, 254507, 254508",
	},
	[1428] = {
		["220:225:707:168"] = "270927",
		["225:220:36:109"] = "270938",
		["245:265:334:114"] = "270912, 270909",
		["256:280:173:101"] = "270919, 270911",
		["270:285:513:99"] = "270922, 270934, 270923, 270937",
		["270:310:589:279"] = "270920, 270914, 270908, 270929",
		["280:355:722:46"] = "270944, 270910, 270935, 270945",
		["294:270:708:311"] = "270906, 270918, 270936, 270942",
		["320:270:377:285"] = "270933, 270943, 270921, 270928",
		["415:315:56:258"] = "270941, 270925, 270926, 270917",
	},
	[1429] = {
		["225:220:422:332"] = "271560",
		["240:220:250:270"] = "271567",
		["255:250:551:292"] = "271573",
		["256:210:704:330"] = "271578",
		["256:237:425:431"] = "271582",
		["256:240:238:428"] = "271576",
		["256:249:577:419"] = "271559",
		["256:256:381:147"] = "271572",
		["256:341:124:327"] = "2212708, 2212709",
		["306:233:696:435"] = "271557, 271583",
		["310:256:587:190"] = "271584, 271565",
		["485:405:0:0"] = "2212713, 2212714, 2212715, 2212716",
	},
	[1430] = {
		["270:270:426:299"] = "271092, 271085, 271086, 271089",
		["300:245:269:337"] = "271095, 271079",
		["380:365:249:76"] = "271075, 271076, 271080, 271081",
	},
	[1431] = {
		["160:330:19:132"] = "271453, 271454",
		["195:145:102:302"] = "2212669",
		["200:175:653:120"] = "271466",
		["220:220:690:353"] = "2212676",
		["220:340:504:117"] = "271470, 271477",
		["235:250:390:382"] = "271449",
		["250:230:539:369"] = "271455",
		["255:285:243:348"] = "271448, 271456",
		["275:250:55:342"] = "271444, 271483",
		["315:280:631:162"] = "271471, 271461, 271450, 271451",
		["350:300:85:149"] = "271473, 271463, 271467, 271464",
		["360:420:298:79"] = "2212678, 2212679, 2212680, 2212681",
		["910:210:89:31"] = "271481, 271460, 271474, 271468",
	},
	[1432] = {
		["195:250:109:370"] = "252899",
		["230:300:125:12"] = "252882, 252883",
		["235:270:229:11"] = "252884, 2212852",
		["255:285:215:348"] = "252886, 252887",
		["256:230:217:203"] = "252898",
		["290:175:339:11"] = "2212855, 2212856",
		["295:358:309:310"] = "252862, 252863, 2212828, 2212829",
		["315:235:542:48"] = "252880, 252881",
		["320:410:352:87"] = "252894, 252895, 252896, 252897",
		["345:256:482:321"] = "252866, 252867",
		["370:295:546:199"] = "252890, 252891, 252892, 252893",
	},
	[1433] = {
		["235:270:399:129"] = "272334, 2212936",
		["250:250:654:161"] = "272372",
		["255:300:500:215"] = "2212977, 2212978",
		["275:256:277:0"] = "272357, 272342",
		["320:210:595:320"] = "272347, 272371",
		["340:195:83:197"] = "272351, 272340",
		["365:245:121:72"] = "272362, 272356",
		["365:350:0:284"] = "272364, 272348, 272358, 272359",
		["430:290:187:333"] = "272344, 272354, 272350, 272339",
		["465:255:484:361"] = "272369, 272363",
		["535:275:133:240"] = "272335, 272343, 2212940, 2212942, 2212943, 2212945",
	},
	[1434] = {
		["105:110:311:131"] = "2213161",
		["105:125:387:64"] = "2213191",
		["110:105:260:132"] = "2213150",
		["110:110:306:301"] = "2213171",
		["110:140:371:129"] = "2213145",
		["115:115:156:42"] = "2213197",
		["120:120:345:276"] = "2213148",
		["125:120:314:493"] = "2213152",
		["125:125:280:368"] = "2213159",
		["125:140:196:3"] = "2213173",
		["128:125:331:59"] = "2213158",
		["128:125:364:231"] = "2213194",
		["128:175:432:94"] = "2213162",
		["140:110:269:26"] = "2213165",
		["145:128:203:433"] = "2213147",
		["155:150:388:0"] = "2213156",
		["165:175:194:284"] = "2213146",
		["165:190:229:422"] = "2213192",
		["170:125:394:212"] = "2213174",
		["170:90:284:0"] = "2213168",
		["190:175:152:90"] = "2213188",
		["200:185:235:189"] = "2213187",
		["245:220:483:8"] = "2213196",
		["90:115:211:359"] = "2213164",
		["90:80:241:92"] = "2213143",
		["95:95:299:88"] = "2213154",
		["95:95:350:335"] = "2213170",
	},
	[1435] = {
		["215:365:724:120"] = "272739, 272746",
		["235:205:171:145"] = "272736",
		["240:245:0:262"] = "2213206",
		["245:305:0:140"] = "272759, 272750",
		["256:668:746:0"] = "272756, 272737, 272769",
		["275:240:129:236"] = "272747, 272763",
		["300:275:565:218"] = "272772, 272760, 2213215, 2213216",
		["315:235:286:110"] = "272768, 272770",
		["345:250:552:378"] = "272740, 272773",
		["360:315:279:237"] = "272742, 272751, 272752, 272764",
		["365:305:492:0"] = "2213200, 2213202, 2213203, 2213204",
	},
	[1436] = {
		["165:200:488:0"] = "273143",
		["195:240:442:241"] = "273137",
		["200:185:208:375"] = "273142",
		["200:240:524:252"] = "273125",
		["210:215:387:11"] = "273145",
		["215:215:307:29"] = "2212528",
		["220:200:317:331"] = "273130",
		["225:205:328:148"] = "273126",
		["225:210:459:105"] = "273146",
		["225:256:220:102"] = "273149",
		["256:175:339:418"] = "273124",
		["280:190:205:467"] = "273141, 2212527",
		["288:235:523:377"] = "273131, 273134",
		["305:210:204:260"] = "273129, 273133",
	},
	[1437] = {
		["175:128:13:314"] = "273156",
		["185:240:456:125"] = "2212531",
		["190:160:628:176"] = "273181",
		["195:185:247:205"] = "273155",
		["200:185:349:115"] = "273173",
		["200:240:237:41"] = "2212533",
		["205:180:401:21"] = "273164",
		["205:245:527:264"] = "273177",
		["225:185:347:218"] = "273159",
		["225:190:89:142"] = "273171",
		["230:190:470:371"] = "273174",
		["240:175:77:245"] = "273163",
		["256:250:507:115"] = "2212535",
		["300:240:92:82"] = "273178, 273167",
		["350:360:611:230"] = "2213613, 2213614, 2212532, 2212534",
	},

	[1438] = {
		["128:100:494:548"] = "2213328",
		["128:190:335:313"] = "272807",
		["160:210:382:281"] = "272826",
		["170:240:272:127"] = "272830",
		["180:256:377:93"] = "272822",
		["185:128:368:443"] = "272814",
		["190:128:462:323"] = "2213323",
		["200:200:561:292"] = "272815",
		["225:225:491:153"] = "272811",
		["256:185:436:380"] = "272810",
		["315:256:101:247"] = "272806, 272812",
	},
	[1439] = {
		["150:215:318:162"] = "769206",
		["170:195:468:85"] = "769211",
		["175:158:329:510"] = "271044",
		["175:183:229:485"] = "769210",
		["180:195:365:181"] = "769207",
		["190:205:324:306"] = "271045",
		["195:215:510:0"] = "271043",
		["200:170:305:412"] = "769209",
		["230:190:375:94"] = "769208",
	},
	[1440] = {
		["128:195:131:137"] = "270380",
		["146:200:856:151"] = "270387",
		["155:150:260:373"] = "270398",
		["165:175:189:324"] = "2212540",
		["180:245:520:238"] = "270402",
		["200:160:796:311"] = "270390",
		["200:205:392:218"] = "2212541",
		["205:185:272:251"] = "270386",
		["210:185:463:141"] = "270400",
		["215:305:205:38"] = "2212542, 2212543",
		["220:195:104:259"] = "2212548",
		["225:255:597:258"] = "270401",
		["235:205:547:426"] = "270375",
		["245:245:19:28"] = "270376",
		["245:255:713:344"] = "270405",
		["255:195:203:158"] = "270389",
		["275:240:356:347"] = "2212544, 2212545",
		["285:185:694:225"] = "270388, 2212547",
	},
	[1441] = {
		["190:190:31:155"] = "272968",
		["205:195:259:131"] = "272962",
		["210:180:205:70"] = "272963",
		["210:190:357:264"] = "272954",
		["210:195:391:192"] = "2213363",
		["240:220:492:250"] = "2213395",
		["250:240:179:200"] = "2213369",
		["305:310:0:0"] = "2213348, 2213349, 2213351, 2213352",
		["320:365:610:300"] = "2213371, 2213372, 2213374, 2213375",
	},
	[1442] = {
		["125:125:475:433"] = "2213093",
		["125:86:663:582"] = "272650",
		["145:107:572:561"] = "272628",
		["150:150:389:320"] = "272646",
		["190:97:718:571"] = "2213087",
		["200:215:390:145"] = "272624",
		["225:120:668:515"] = "2213088",
		["230:355:210:234"] = "272633, 272647",
		["270:205:247:0"] = "272632, 272641",
		["288:355:457:282"] = "272648, 272634, 272635, 272623",
		["320:275:553:197"] = "272630, 272649, 272642, 272636",
	},
	[1443] = {
		["100:100:241:6"] = "2212638",
		["170:160:555:181"] = "2212635",
		["190:220:447:102"] = "271111",
		["195:242:293:426"] = "271122",
		["200:250:554:0"] = "271114",
		["205:145:431:0"] = "271126",
		["205:195:690:444"] = "271105",
		["205:250:311:61"] = "2212632",
		["205:285:590:365"] = "2212636, 2212637",
		["220:220:607:215"] = "2212634",
		["230:230:167:389"] = "271125",
		["245:285:212:215"] = "271106, 271129",
		["275:250:387:244"] = "271127, 2212633",
		["285:245:625:33"] = "271104, 271124",
		["285:280:399:380"] = "271108, 271112, 271113, 271109",
	},
	[1444] = {
		["110:110:493:70"] = "2212732",
		["110:170:478:386"] = "2212728",
		["115:115:486:329"] = "2212726",
		["120:195:623:167"] = "2212729",
		["140:165:690:141"] = "271696",
		["145:320:404:256"] = "271700, 271682",
		["150:125:454:0"] = "2212721",
		["155:160:689:233"] = "271675",
		["180:180:208:234"] = "2212734",
		["190:155:305:0"] = "2212733",
		["190:250:540:320"] = "271699",
		["215:293:192:375"] = "2212730, 2212731",
		["225:180:751:198"] = "271680",
		["230:195:454:201"] = "271687",
		["240:220:618:298"] = "2212735",
		["285:245:319:75"] = "271705, 271686",
	},
	[1445] = {
		["200:195:660:21"] = "271494",
		["230:205:534:224"] = "271500",
		["250:315:422:0"] = "271507, 271504",
		["255:250:257:313"] = "2212689",
		["280:270:230:0"] = "2212685, 2212686, 2212687, 2212688",
		["285:240:367:381"] = "271503, 271509",
		["400:255:239:189"] = "2212683, 2212684",
	},
	[1446] = {
		["110:140:611:147"] = "2213315",
		["110:180:473:234"] = "272800",
		["120:135:533:104"] = "2213275",
		["150:160:291:434"] = "2213311",
		["155:150:561:256"] = "272789",
		["155:150:592:75"] = "2213281",
		["160:150:395:346"] = "272798",
		["160:190:629:220"] = "2213273",
		["165:180:509:168"] = "2213313",
		["175:165:421:91"] = "272774",
		["180:200:252:199"] = "272792",
		["185:250:203:286"] = "272781",
		["195:175:299:100"] = "272776",
		["195:210:323:359"] = "272784",
		["205:145:325:289"] = "272782",
		["205:157:445:511"] = "272801",
		["210:175:254:0"] = "272788",
		["215:175:499:293"] = "272795",
		["215:180:363:194"] = "272799",
		["220:210:449:372"] = "272805",
	},
	[1447] = {
		["120:155:818:107"] = "270434",
		["145:215:422:95"] = "2212573",
		["160:210:404:194"] = "270412",
		["190:200:681:153"] = "2212567",
		["200:150:77:331"] = "2212555",
		["215:175:84:229"] = "2212574",
		["220:255:191:369"] = "2212554",
		["225:180:35:422"] = "2212564",
		["235:140:478:44"] = "2212560",
		["235:270:250:106"] = "2212571, 2212572",
		["240:125:552:499"] = "270410",
		["240:155:499:119"] = "2212568",
		["245:185:644:40"] = "270432",
		["265:280:238:221"] = "270414, 2212561, 2212562, 2212563",
		["270:300:479:201"] = "2212550, 2212551, 2212552, 2212553",
		["315:200:296:429"] = "270409, 2212559",
		["370:220:389:353"] = "2212565, 2212566",
		["395:128:396:540"] = "2212569, 2212570",
		["570:170:366:0"] = "2212556, 2212557, 2212558",
	},
	[1448] = {
		["145:159:496:509"] = "271657",
		["160:145:548:90"] = "271653",
		["165:155:332:465"] = "271663",
		["175:135:408:533"] = "271658",
		["185:160:405:429"] = "271659",
		["195:170:330:29"] = "271652",
		["215:215:420:54"] = "271673",
		["235:145:292:263"] = "271666",
		["235:155:297:381"] = "271664",
		["235:200:307:123"] = "271665",
		["240:145:483:0"] = "271660",
		["245:128:271:331"] = "271669",
	},
	[1449] = {
		["285:285:582:67"] = "273051, 2213483, 2213484, 2213486",
		["295:270:367:178"] = "273042, 273065, 273050, 273036",
		["310:355:560:240"] = "273072, 273039, 273037, 273063",
		["315:345:121:151"] = "273043, 273075, 273069, 273061",
		["345:285:158:368"] = "273046, 273053, 273071, 273047",
		["345:285:367:380"] = "273059, 273066, 273073, 273054",
		["570:265:160:6"] = "273052, 273062, 273057, 273058, 2213490, 2213491",
	},
	[1450] = { ["555:510:244:89"] = "252844, 252845, 252846, 252847, 2212870, 2212872" },
	[1451] = {
		["288:256:116:413"] = "272564, 272553",
		["320:256:344:197"] = "272573, 272545",
		["320:289:104:24"] = "272581, 272562, 2213052, 2213053",
		["384:384:500:65"] = "272580, 272544, 2213048, 2213049",
		["384:512:97:144"] = "272559, 272543, 272574, 272575",
		["512:320:265:12"] = "272565, 272566, 272577, 272546",
		["512:384:245:285"] = "272567, 272547, 272555, 272548",
	},
	[1452] = {
		["125:165:611:242"] = "273206",
		["145:125:617:158"] = "273200",
		["165:140:593:340"] = "273199",
		["165:200:509:107"] = "273191",
		["175:185:555:27"] = "273203",
		["185:160:392:137"] = "273207",
		["185:180:493:258"] = "273185",
		["200:160:523:376"] = "273198",
		["215:185:401:198"] = "273192",
		["230:120:229:243"] = "273187",
		["240:140:222:172"] = "273202",
		["250:180:368:7"] = "273184",
		["255:205:447:441"] = "2213650",
	},

	[1459] = {
		["235:290:399:375"] = "270314, 270315",
		["270:240:348:13"] = "270331, 270325",
		["300:300:335:172"] = "270320, 270321, 270322, 270323",
	},
}

local world_map_overlay = {}
local map_container = CreateFrame("Frame")
map_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
map_container:SetSize(100, 100)
map_container:Show()
local map_textures = {}
for i = 1, 12 do
	map_textures[i] = map_container:CreateTexture(nil, "OVERLAY")
	map_textures[i]:SetDrawLayer("OVERLAY", 2)
	map_textures[i]:SetVertexColor(1, 1, 1, 1)
end
map_textures[1]:SetPoint("TOPLEFT", map_container, "TOPLEFT", 0, 0)
map_textures[2]:SetPoint("LEFT", map_textures[1], "RIGHT", 0, 0)
map_textures[3]:SetPoint("LEFT", map_textures[2], "RIGHT", 0, 0)
map_textures[4]:SetPoint("LEFT", map_textures[3], "RIGHT", 0, 0)
map_textures[5]:SetPoint("TOP", map_textures[1], "BOTTOM", 0, 0)
map_textures[6]:SetPoint("LEFT", map_textures[5], "RIGHT", 0, 0)
map_textures[7]:SetPoint("LEFT", map_textures[6], "RIGHT", 0, 0)
map_textures[8]:SetPoint("LEFT", map_textures[7], "RIGHT", 0, 0)
map_textures[9]:SetPoint("TOP", map_textures[5], "BOTTOM", 0, 0)
map_textures[10]:SetPoint("LEFT", map_textures[9], "RIGHT", 0, 0)
map_textures[11]:SetPoint("LEFT", map_textures[10], "RIGHT", 0, 0)
map_textures[12]:SetPoint("LEFT", map_textures[11], "RIGHT", 0, 0)

local map_texture_masks = {}
map_texture_masks[1] = map_container:CreateMaskTexture()
map_texture_masks[1]:SetRotation(3.14 + 3.14 / 2)
map_texture_masks[1]:SetPoint("CENTER", map_textures[1], "CENTER", 0, 0)
map_texture_masks[1]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\corner_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[1]:AddMaskTexture(map_texture_masks[1])

map_texture_masks[4] = map_container:CreateMaskTexture()
map_texture_masks[4]:SetRotation(3.14)
map_texture_masks[4]:SetPoint("CENTER", map_textures[4], "CENTER", -30, 0)
map_texture_masks[4]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\corner_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[4]:AddMaskTexture(map_texture_masks[4])

map_texture_masks[9] = map_container:CreateMaskTexture()
map_texture_masks[9]:SetPoint("CENTER", map_textures[9], "CENTER", 0, 65)
map_texture_masks[9]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\corner_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[9]:AddMaskTexture(map_texture_masks[9])

map_texture_masks[12] = map_container:CreateMaskTexture()
map_texture_masks[12]:SetPoint("CENTER", map_textures[12], "CENTER", -30, 65)
map_texture_masks[12]:SetRotation(3.14 / 2)
map_texture_masks[12]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\corner_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[12]:AddMaskTexture(map_texture_masks[12])

map_texture_masks[2] = map_container:CreateMaskTexture()
map_texture_masks[2]:SetPoint("CENTER", map_textures[2], "CENTER", 0, 0)
map_texture_masks[2]:SetRotation(3.14)
map_texture_masks[2]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[2]:AddMaskTexture(map_texture_masks[2])
map_texture_masks[3] = map_container:CreateMaskTexture()
map_texture_masks[3]:SetPoint("CENTER", map_textures[3], "CENTER", 0, 0)
map_texture_masks[3]:SetRotation(3.14)
map_texture_masks[3]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[3]:AddMaskTexture(map_texture_masks[3])

map_texture_masks[10] = map_container:CreateMaskTexture()
map_texture_masks[10]:SetPoint("CENTER", map_textures[10], "CENTER", 0, 65)
map_texture_masks[10]:SetRotation(0)
map_texture_masks[10]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[10]:AddMaskTexture(map_texture_masks[10])
map_texture_masks[11] = map_container:CreateMaskTexture()
map_texture_masks[11]:SetPoint("CENTER", map_textures[11], "CENTER", 0, 65)
map_texture_masks[11]:SetRotation(0)
map_texture_masks[11]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[11]:AddMaskTexture(map_texture_masks[11])

map_texture_masks[5] = map_container:CreateMaskTexture()
map_texture_masks[5]:SetPoint("CENTER", map_textures[5], "CENTER", 0, 0)
map_texture_masks[5]:SetRotation(3.14 + 3.14 / 2)
map_texture_masks[5]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[5]:AddMaskTexture(map_texture_masks[5])

map_texture_masks[8] = map_container:CreateMaskTexture()
map_texture_masks[8]:SetPoint("CENTER", map_textures[8], "CENTER", -30, 0)
map_texture_masks[8]:SetRotation(3.14 - 3.14 / 2)
map_texture_masks[8]:SetTexture(
	"Interface\\Addons\\Deathlog\\Media\\side_blur.blp",
	"CLAMPTOBLACKADDITIVE",
	"CLAMPTOBLACKADDITIVE"
)
map_textures[8]:AddMaskTexture(map_texture_masks[8])

local function createMapHighlightButton(
	name,
	topleft,
	scalex,
	scaley,
	button_topleft,
	button_scalex,
	button_scaley,
	map_id
)
	local button = CreateFrame("Button", "DeathlogHighlightButton" .. name, map_container)
	button.map_id = map_id
	button.Texture = button:CreateTexture(button:GetName() .. "Texture", "BACKGROUND")
	button.Texture:Hide()
	button.HighlightTexture = button:CreateTexture(button:GetName() .. "HighlightTexture", "HIGHLIGHT")
	button.HighlightTexture:SetBlendMode("ADD")
	button.HighlightTexture:SetAllPoints(button.Texture)
	button.HighlightTexture:SetTexture("Interface\\WorldMap\\" .. name .. "\\" .. name .. "Highlight.PNG")
	button:Hide()

	button.topleft = topleft
	button.scalex = scalex
	button.scaley = scaley

	button.button_topleft = button_topleft
	button.button_scalex = button_scalex
	button.button_scaley = button_scaley
	return button
end

local overlay_highlight = map_container:CreateTexture(nil, "OVERLAY")
overlay_highlight:SetDrawLayer("OVERLAY", 6)
overlay_highlight:SetBlendMode("ADD")
overlay_highlight:Hide()

local this_map_id = nil
local occupied_by_creature = nil
function Deathlog_MapContainer_showSkullSet(source_id)
	Deathlog_MapContainer_resetSkullSet()
	if precomputed_heatmap_creature_subset == nil then
		return
	end
	if precomputed_heatmap_creature_subset[this_map_id] == nil then
		return
	end
	if precomputed_heatmap_creature_subset[this_map_id][source_id] == nil then
		return
	end

	occupied_by_creature = {}
	for x, v in pairs(precomputed_heatmap_creature_subset[this_map_id][source_id]) do
		for y, _ in pairs(v) do
			if occupied_by_creature[x + 1] == nil then
				occupied_by_creature[x + 1] = { [y + 1] = 1 }
			end
			occupied_by_creature[x + 1][y + 1] = 1
		end
	end

	for i = 1, 100 do
		for j = 1, 100 do
			if map_container.heatmap[i][j].intensity > 0.01 then
				local alpha = map_container.heatmap[i][j].intensity * 4
				if alpha > 0.6 then
					alpha = 0.6
				end
				if map_container.heatmap[i][j].intensity > 0.02 then
					if occupied_by_creature == nil or (occupied_by_creature[i] and occupied_by_creature[i][j]) then
						map_container.heatmap[i][j]:SetColorTexture(
							1.0,
							1.1 - map_container.heatmap[i][j].intensity * 4,
							0.1,
							alpha
						)
					else
						map_container.heatmap[i][j]:SetColorTexture(
							1.0,
							1.1 - map_container.heatmap[i][j].intensity * 4,
							0.1,
							alpha * 0.01
						)
					end
				else
					map_container.heatmap[i][j]:SetColorTexture(
						1.0,
						1.1 - map_container.heatmap[i][j].intensity * 4,
						0.1,
						0
					)
				end
				if map_container.heatmap_checkbox:GetChecked() then
					map_container.heatmap[i][j]:Show()
				else
					map_container.heatmap[i][j]:Hide()
				end
			end
		end
	end
end

function Deathlog_MapContainer_resetSkullSet()
	occupied_by_creature = nil

	for i = 1, 100 do
		for j = 1, 100 do
			if map_container.heatmap[i][j].intensity > 0.01 then
				local alpha = map_container.heatmap[i][j].intensity * 4
				if alpha > 0.6 then
					alpha = 0.6
				end
				if map_container.heatmap[i][j].intensity > 0.02 then
					if occupied_by_creature == nil or (occupied_by_creature[i] and occupied_by_creature[i][j]) then
						map_container.heatmap[i][j]:SetColorTexture(
							1.0,
							1.1 - map_container.heatmap[i][j].intensity * 4,
							0.1,
							alpha
						)
					else
						map_container.heatmap[i][j]:SetColorTexture(
							1.0,
							1.1 - map_container.heatmap[i][j].intensity * 4,
							0.1,
							alpha * 0.01
						)
					end
				else
					map_container.heatmap[i][j]:SetColorTexture(
						1.0,
						1.1 - map_container.heatmap[i][j].intensity * 4,
						0.1,
						0
					)
				end
				if map_container.heatmap_checkbox:GetChecked() then
					map_container.heatmap[i][j]:Show()
				else
					map_container.heatmap[i][j]:Hide()
				end
			end
		end
	end
end

function map_container.updateMenuElement(scroll_frame, current_map_id, stats_tbl, setMapRegion)
	-- local _skull_locs = stats_tbl["skull_locs"]
	this_map_id = current_map_id
	if scroll_frame.frame then
		map_container:SetParent(scroll_frame.frame)
		map_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -65)
		map_container:SetHeight(scroll_frame.frame:GetWidth() * 0.6 * 3 / 4)
		map_container:SetWidth(scroll_frame.frame:GetWidth() * 0.6)
	else
		map_container:SetParent(scroll_frame)
		map_container:SetPoint("TOPLEFT", scroll_frame, "TOPLEFT", 0, -65)
		map_container:SetHeight(scroll_frame:GetWidth() * 0.6 * 3 / 4)
		map_container:SetWidth(scroll_frame:GetWidth() * 0.6)
	end
	map_container:Show()
	if map_container.map_hint == nil then
		map_container.map_hint = map_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		map_container.map_hint:SetPoint("BOTTOM", map_container, "BOTTOM", 0, 60)
		map_container.map_hint:SetFont(Deathlog_L.menu_font, 14, "")
		map_container.map_hint:SetTextColor(0.8, 0.8, 0.8, 0.8)
		map_container.map_hint:SetJustifyH("CENTER")
		map_container.map_hint:SetText("Click to explore statistics for a region.")
		map_container.map_hint:Show()
	end
	if map_container.heatmap_checkbox == nil then
		map_container.heatmap_checkbox =
			CreateFrame("CheckButton", "DeathlogHeatmapCheckbox", map_container, "ChatConfigCheckButtonTemplate")
		map_container.heatmap_checkbox:SetPoint("TOPLEFT", 25, 25)
		map_container.heatmap_checkbox:SetHitRectInsets(0, -75, 0, 0)
		map_container.heatmap_checkbox:SetChecked(true)
		map_container.heatmap_checkbox:Show()

		map_container.heatmap_checkbox.label = map_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		map_container.heatmap_checkbox.label:SetPoint("LEFT", map_container.heatmap_checkbox, "RIGHT", 0, 0)
		map_container.heatmap_checkbox.label:SetFont(Deathlog_L.menu_font, 14, "OUTLINE")
		map_container.heatmap_checkbox.label:SetTextColor(0.9, 0.9, 0.9)
		map_container.heatmap_checkbox.label:SetJustifyH("RIGHT")
		map_container.heatmap_checkbox.label:SetText(Deathlog_L.show_heatmap)
		map_container.heatmap_checkbox.label:Show()
	end
	if map_container.heatmap_checkbox then
		map_container.heatmap_checkbox:SetScript("OnClick", function(self)
			setMapRegion(current_map_id)
		end)
	end

	if map_container.darken_checkbox == nil then
		map_container.darken_checkbox =
			CreateFrame("CheckButton", "DeathlogHeatmapCheckbox", map_container, "ChatConfigCheckButtonTemplate")
		map_container.darken_checkbox:SetPoint("TOPLEFT", 150, 25)
		map_container.darken_checkbox:SetHitRectInsets(0, -75, 0, 0)
		map_container.darken_checkbox:SetChecked(true)
		map_container.darken_checkbox:Show()

		map_container.darken_checkbox.label = map_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		map_container.darken_checkbox.label:SetPoint("LEFT", map_container.darken_checkbox, "RIGHT", 0, 0)
		map_container.darken_checkbox.label:SetFont(Deathlog_L.menu_font, 14, "OUTLINE")
		map_container.darken_checkbox.label:SetTextColor(0.9, 0.9, 0.9)
		map_container.darken_checkbox.label:SetJustifyH("RIGHT")
		map_container.darken_checkbox.label:SetText("Darken")
		map_container.darken_checkbox.label:Show()
	end
	if map_container.darken_checkbox then
		map_container.darken_checkbox:SetScript("OnClick", function(self)
			setMapRegion(current_map_id)
		end)
	end

	local layers = C_Map.GetMapArtLayerTextures(current_map_id, 1)
	if layers == nil then
		return
	end
	for i = 1, 12 do
		map_textures[i]:SetHeight(map_container:GetWidth() / 4)
		map_textures[i]:SetWidth(map_container:GetWidth() / 4)
		map_textures[i]:SetTexture(layers[i])
		map_textures[i]:Show()
		if map_texture_masks[i] then
			map_texture_masks[i]:SetHeight(map_textures[i]:GetWidth() * 1.02)
			map_texture_masks[i]:SetWidth(map_textures[i]:GetWidth() * 1.02)
		end
	end

	for _, v in ipairs(world_map_overlay) do
		v:Hide()
	end
	other_texs = {}

	local function getOverlayTextures(current_map_id)
		local textures = {}
		if overlay_info[current_map_id] == nil then
			return nil
		end
		for k, v in pairs(overlay_info[current_map_id]) do
			local textureWidth, textureHeight, offsetX, offsetY = string.split(":", k)
			local fileDataIDs = { string.split(",", v) }
			table.insert(textures, {
				["fileDataIDs"] = fileDataIDs,
				["textureWidth"] = textureWidth,
				["textureHeight"] = textureHeight,
				["offsetX"] = offsetX,
				["offsetY"] = offsetY,
			})
		end
		return textures
	end

	local textures = getOverlayTextures(current_map_id)
	if textures ~= nil then
		local textureCount = 0
		for k, v in ipairs(textures) do
			local numTexturesWide = ceil(v["textureWidth"] / 256)
			local numTexturesTall = ceil(v["textureHeight"] / 256)
			local neededTextures = textureCount + (numTexturesWide * numTexturesTall)
			if neededTextures > #world_map_overlay then
				for j = #world_map_overlay + 1, neededTextures do
					world_map_overlay[j] = map_container:CreateTexture(nil, "OVERLAY")
				end
			end
			local texturePixelWidth, textureFileWidth, texturePixelHeight, textureFileHeight
			for j = 1, numTexturesTall do
				if j < numTexturesTall then
					texturePixelHeight = 256
					textureFileHeight = 256
				else
					texturePixelHeight = mod(v["textureHeight"], 256)
					if texturePixelHeight == 0 then
						texturePixelHeight = 256
					end
					textureFileHeight = 16
					while textureFileHeight < texturePixelHeight do
						textureFileHeight = textureFileHeight * 2
					end
				end

				for k = 1, numTexturesWide do
					textureCount = textureCount + 1
					local texture = world_map_overlay[textureCount]
					if k < numTexturesWide then
						texturePixelWidth = 256
						textureFileWidth = 256
					else
						texturePixelWidth = mod(v["textureWidth"], 256)
						if texturePixelWidth == 0 then
							texturePixelWidth = 256
						end
						textureFileWidth = 16
						while textureFileWidth < texturePixelWidth do
							textureFileWidth = textureFileWidth * 2
						end
					end
					texture:SetWidth(texturePixelWidth * map_container:GetWidth() / 1000)
					texture:SetHeight(texturePixelHeight * map_container:GetWidth() / 1000)
					texture:SetTexCoord(
						0,
						texturePixelWidth / textureFileWidth,
						0,
						texturePixelHeight / textureFileHeight
					)
					texture:SetPoint(
						"TOPLEFT",
						map_textures[1],
						"TOPLEFT",
						(v["offsetX"] + (256 * (k - 1))) * map_container:GetWidth() / 1000 - 5,
						-(v["offsetY"] + (256 * (j - 1))) * map_container:GetWidth() / 1000 + 5
					)
					texture:SetTexture(v["fileDataIDs"][((j - 1) * numTexturesWide) + k], nil, nil, "TRILINEAR")
					if map_container.darken_checkbox:GetChecked() then
						texture:SetVertexColor(0.6, 0.6, 1)
					else
						texture:SetVertexColor(1, 1, 1)
					end

					texture:SetDrawLayer("OVERLAY", 5)
					texture:Show()
				end
			end
		end
	end

	local num_entries = 1
	local modified_width = map_container:GetWidth() * 0.98
	local modified_height = map_container:GetHeight() * 0.87
	if map_container.tomb_tex == nil then
		map_container.tomb_tex = {}
	end
	-- if _skull_locs[current_map_id] then
	-- 	for idx = 1, 100 do
	-- 		if map_container.tomb_tex[idx] == nil then
	-- 			map_container.tomb_tex[idx] = map_container:CreateTexture(nil, "OVERLAY")
	-- 			map_container.tomb_tex[idx]:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
	-- 			map_container.tomb_tex[idx]:SetDrawLayer("OVERLAY", 7)
	-- 			map_container.tomb_tex[idx]:SetHeight(15)
	-- 			map_container.tomb_tex[idx]:SetWidth(15)
	-- 			map_container.tomb_tex[idx]:Hide()
	-- 		end

	-- 		map_container.tomb_tex[idx].map_id = current_map_id
	-- 	end
	-- end

	local modified_width = map_container:GetWidth() * 0.98
	local modified_height = map_container:GetHeight() * 0.87
	if map_container.heatmap == nil then
		map_container.heatmap = {}
		for i = 1, 100 do
			map_container.heatmap[i] = {}
			for j = 1, 100 do
				map_container.heatmap[i][j] = map_container:CreateTexture(nil, "OVERLAY")
				map_container.heatmap[i][j]:SetDrawLayer("OVERLAY", 6)
				map_container.heatmap[i][j]:SetHeight(5)
				map_container.heatmap[i][j]:SetColorTexture(1.0, 0.1, 0.1, 0)
				map_container.heatmap[i][j]:SetWidth(7)
				map_container.heatmap[i][j]:SetPoint(
					"CENTER",
					map_container,
					"TOPLEFT",
					modified_width * i / 100,
					-modified_height * j / 100
				)
				map_container.heatmap[i][j]:Show()
				map_container.heatmap[i][j].intensity = 0.0
			end
		end
	end

	for i = 1, 100 do
		for j = 1, 100 do
			map_container.heatmap[i][j]:SetPoint(
				"CENTER",
				map_container,
				"TOPLEFT",
				modified_width * i / 100,
				-modified_height * j / 100
			)
			map_container.heatmap[i][j]:Hide()
		end
	end

	for i = 1, 100 do
		for j = 1, 100 do
			map_container.heatmap[i][j].intensity = 0.0
		end
	end
	local iv = {
		[1] = {
			[1] = 0.025,
			[2] = 0.045,
			[3] = 0.025,
		},
		[2] = {
			[1] = 0.045,
			[2] = 0.1,
			[3] = 0.045,
		},
		[3] = {
			[1] = 0.025,
			[2] = 0.045,
			[3] = 0.025,
		},
	}
	if current_map_id ~= 947 then
		for x, v2 in pairs(precomputed_heatmap_intensity[current_map_id]) do
			for y, intensity in pairs(v2) do
				map_container.heatmap[x][y].intensity = intensity
			end
		end
	end

	local c = 0
	for i = 1, 100 do
		for j = 1, 100 do
			if map_container.heatmap[i][j].intensity > 0.01 then
				local alpha = map_container.heatmap[i][j].intensity * 4
				if alpha > 0.6 then
					alpha = 0.6
				end
				if map_container.heatmap[i][j].intensity > 0.02 then
					if occupied_by_creature == nil or (occupied_by_creature[i] and occupied_by_creature[i][j]) then
						map_container.heatmap[i][j]:SetColorTexture(
							1.0,
							1.1 - map_container.heatmap[i][j].intensity * 4,
							0.1,
							alpha
						)
					else
						map_container.heatmap[i][j]:SetColorTexture(
							1.0,
							1.1 - map_container.heatmap[i][j].intensity * 4,
							0.1,
							alpha * 0.01
						)
					end
					c = c + 1
				else
					map_container.heatmap[i][j]:SetColorTexture(
						1.0,
						1.1 - map_container.heatmap[i][j].intensity * 4,
						0.1,
						0
					)
				end
				if map_container.heatmap_checkbox:GetChecked() then
					map_container.heatmap[i][j]:Show()
				else
					map_container.heatmap[i][j]:Hide()
				end
			end
		end
	end

	map_container:SetScript("OnUpdate", function()
		local x, y = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		local ratio = GetScreenWidth() / GetScreenHeight()
		local modified_width = map_container:GetWidth() * 0.98
		local modified_height = map_container:GetHeight() * 0.87

		x = x / s
		y = y / s

		if x < map_container:GetLeft() or x > map_container:GetRight() then
			return
		end
		if y < map_container:GetTop() - modified_height or y > map_container:GetTop() then
			return
		end
		local l_x = (x - map_container:GetLeft()) / modified_width
		local l_y = -(y - map_container:GetTop()) / modified_height

		info = C_Map.GetMapInfoAtPosition(current_map_id, l_x, l_y)

		if info ~= nil then
			local fileDataID, atlasID, texturePercentageX, texturePercentageY, textureX, textureY, scrollChildX, scrollChildY =
				C_Map.GetMapHighlightInfoAtPosition(current_map_id, l_x, l_y)
			if fileDataID and textureX > 0 and textureY > 0 then
				overlay_highlight:SetTexture(fileDataID)
				overlay_highlight:SetPoint(
					"TOPLEFT",
					map_textures[1],
					"TOPLEFT",
					scrollChildX * modified_width,
					-scrollChildY * modified_height
				)
				overlay_highlight:SetWidth(textureX * modified_width)
				overlay_highlight:SetHeight(textureY * modified_height)
				overlay_highlight:SetTexCoord(0, texturePercentageX, 0, texturePercentageY)
				overlay_highlight:SetDrawLayer("OVERLAY", 3)
				overlay_highlight:Show()
			end
		end
	end)

	map_container:SetScript("OnMouseDown", function(self, button)
		if map_container.tomb_tex then
			for _, v in ipairs(map_container.tomb_tex) do
				v:Hide()
			end

			for _, v in pairs(map_container.heatmap) do
				for _, v2 in pairs(v) do
					v2.intensity = 0
					v2:Hide()
				end
			end
		end
		if button == "RightButton" then
			info = C_Map.GetMapInfo(current_map_id)
			if info and info.parentMapID then
				parent_info = C_Map.GetMapInfo(info.parentMapID)
				if parent_info then
					setMapRegion(info.parentMapID, parent_info.name)
					overlay_highlight:Hide()
				end
			end
		end
		if button == "LeftButton" then
			local x, y = GetCursorPosition()
			local s = UIParent:GetEffectiveScale()
			local ratio = GetScreenWidth() / GetScreenHeight()
			local modified_width = map_container:GetWidth() * 0.98
			local modified_height = map_container:GetHeight() * 0.87

			x = x / s
			y = y / s

			if x < map_container:GetLeft() or x > map_container:GetRight() then
				return
			end
			if y < map_container:GetTop() - modified_height or y > map_container:GetTop() then
				return
			end
			local l_x = (x - map_container:GetLeft()) / modified_width
			local l_y = -(y - map_container:GetTop()) / modified_height

			info = C_Map.GetMapInfoAtPosition(current_map_id, l_x, l_y)
			if info then
				overlay_highlight:Hide()
				setMapRegion(info.mapID, info.name)
				Deathlog_MapContainer_resetSkullSet()
			end
		end
	end)

	map_container:SetScript("OnHide", function()
		for _, v in ipairs(map_container.tomb_tex) do
			v:Hide()
		end
		for _, v in ipairs(map_container.heatmap) do
			for _, v2 in pairs(v) do
				v2.intensity = 0
				v2:Hide()
			end
		end

		map_container.darken_checkbox:Hide()
		map_container.darken_checkbox.label:Hide()

		map_container.heatmap_checkbox:Hide()
		map_container.heatmap_checkbox.label:Hide()
		map_container.map_hint:Hide()

		for _, v in ipairs(world_map_overlay) do
			v:Hide()
		end
	end)

	map_container:SetScript("OnShow", function()
		map_container.darken_checkbox:Show()
		map_container.darken_checkbox.label:Show()

		map_container.heatmap_checkbox:Show()
		map_container.heatmap_checkbox.label:Show()
		map_container.map_hint:Show()
	end)
end

function Deathlog_MapContainer()
	return map_container
end
