<?php

namespace kumy\ResticBackup\FieldTypes;

use OPNsense\Base\FieldTypes\TextField;

class TextOrGlobalDefaultField extends TextField
{
    protected $internalDefaultValue = "global default";
    protected $internalInitialValue = "global default";
    protected $internalValue = "global default";
}
