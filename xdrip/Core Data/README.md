**alerts**

There's different kinds of alerts : high, low, very high, very low, iPhone muted.
For each kind of alert, one can define per minute of the day, which alerttype should be applied. Example between 00:00 and 08:00 high alert should have specific sound, between 08:00 and 23:59, high alert should not have sound but only vibrate. 
In this example there would be two alerttypes, the high alert would have two alertentries, one with start 0, another with start 480 (480
minutes = 08:00).

The alerttypes can be reused for other kinds of alerts.

alerttype 
Each alertentry must have an alerttype.
- name, name of the alert type as shown to user, chosen by user
- enabled, enabled or not enabled, if not enabled, then the alerts that use this alert type will simply never go off
- vibrate, vibrate yes or no
- snooze, snooze via notification yes or no, should it be possible to snooze the alert via the home screen
- snoozeperiod,  If snooze = yes, then the value defines how long the alert will be snoozed if the user snoozes
from the home screen
- soundname?, name of the sound as stored in the assets - if not present then default ios sound to use

alertentry
Each alert has a list of alertentries. 
- start, start time in minutes from 0 to 24*60 (first needs be 0) - as of when is the alert applicable, till the next entry
- value, the value 
- alerttype, applicable alerttype for the period
- alert, the alert to which the entry belongs


alert
- type,  defines the kind of alert : high, very low, very high, ... there's a predefined list
- alertEntries, list of alertentry's