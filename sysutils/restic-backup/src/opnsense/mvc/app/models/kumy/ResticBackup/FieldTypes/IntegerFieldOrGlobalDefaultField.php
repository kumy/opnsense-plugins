<?php

namespace kumy\ResticBackup\FieldTypes;

use OPNsense\Base\FieldTypes\IntegerField;

class IntegerFieldOrGlobalDefaultField extends IntegerField
{
    protected $internalDefaultValue = "global default";
    protected $internalInitialValue = "global default";
    protected $internalValue = "global default";
}
