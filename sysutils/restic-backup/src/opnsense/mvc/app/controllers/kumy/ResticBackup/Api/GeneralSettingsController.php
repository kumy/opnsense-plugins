<?php

namespace kumy\ResticBackup\Api;

use OPNsense\Core\Backend;
use OPNsense\Core\Config;
use OPNsense\Cron\Cron;

class GeneralSettingsController extends BaseSettings
{
    protected static $internalModelClass = '\kumy\ResticBackup\GeneralSettings';
    protected static $internalModelName = 'restic';

    /**
     * create new cron job or return already available one
     * Note: Code taken from AcmeClient plugin
     *
     * @return array status action
     * @throws \ReflectionException
     * @throws \Exception
     */
    public function fetchCronIntegrationAction()
    {
        $result = ["result" => "no change"];

        if (!$this->request->isPost()) {
            return $result;
        }

        $mdlRestic = $this->getModel();
        $backend = new Backend();
        // Setup cronjob if AcmeClient and AutoRenewal is enabled.
        if (
            empty((string)$mdlRestic->UpdateCron) &&
            (string)$mdlRestic->cronjob &&
            (string)$mdlRestic->enabled
        ) {
            $mdlCron = new Cron();
            // NOTE: Only configd actions are valid commands for cronjobs
            //       and they *must* provide a description that is not empty.
            $cron_uuid = $mdlCron->newDailyJob(
                "ResticBackup",
                "restic backup",
                "Scheduled ResticBackup",
                "*",
                "1"
            );
            $mdlRestic->UpdateCron = $cron_uuid;

            // Save updated configuration.
            $validation_result = $mdlCron->performValidation();
            if (!$validation_result->count()) {
                $mdlCron->serializeToConfig();
                // save data to config, do not validate because the current in memory model doesn't know about the
                // cron item just created.
                $mdlRestic->serializeToConfig(false, true);
                Config::getInstance()->save();
                // Refresh the crontab
                $backend->configdRun('template reload OPNsense/Cron');
                // (res)start daemon
                $backend->configdRun("cron restart");
                $result['result'] = "new";
                $result['uuid'] = $cron_uuid;
            } else {
                $result['result'] = join(" ; ", (array)$validation_result->getMessages());
            }
        // Delete cronjob if ResticBackup or cronjob is disabled.
        } elseif (
            !empty((string)$mdlRestic->UpdateCron) && (
                !(string)$mdlRestic->cronjob ||
                !(string)$mdlRestic->enabled
            )
        ) {
            // Get UUID, clean existing entry
            $cron_uuid = (string)$mdlRestic->UpdateCron;
            $mdlRestic->UpdateCron = "";
            $mdlCron = new Cron();
            // Delete the cronjob item
            if ($mdlCron->jobs->job->del($cron_uuid)) {
                // If item is removed, serialize to config and save
                $mdlCron->serializeToConfig();
                $mdlRestic->serializeToConfig(false, true);
                Config::getInstance()->save();
                // Regenerate the crontab
                $backend->configdRun('template reload OPNsense/Cron');
                // (res)start daemon
                $backend->configdRun("cron restart");
                $result['result'] = "deleted";
            } else {
                $result['result'] = "unable to delete cron";
            }
        }

        return $result;
    }
}
