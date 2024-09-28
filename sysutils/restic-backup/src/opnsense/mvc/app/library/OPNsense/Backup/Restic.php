<?php

namespace OPNsense\Backup;

use kumy\ResticBackup\Api\BaseSettings;
use kumy\ResticBackup\GeneralSettings;
use OPNsense\Core\Backend;

/**
 * Class Restic backup
 * @package OPNsense\Backup
 */
class Restic extends Base implements IBackupProvider
{

    public function getConfigurationFields()
    {
        $fields = [
           [
              "name" => 'info',
              "type" => 'info',
              "label" => sprintf('%s <a href="/ui/resticbackup">System > %s</a>', gettext("See"),  BaseSettings::PLUGIN_NAME),
              "value" => null
           ],
        ];
        return $fields;
    }

    public function setConfiguration($conf)
    {
        // No configuration managed here. User must go to the plugin dedicated page.
        return [];
    }

    public function getName()
    {
        return gettext("Restic");
    }

    public function backup()
    {
        $backend = new Backend();
        return explode("\n", $backend->configdRun("restic ls latest"));
    }

    public function isEnabled()
    {
        return (string)(new GeneralSettings())->enabled === "1";
    }
}
