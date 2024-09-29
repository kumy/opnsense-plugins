<?php

namespace kumy\ResticBackup;

use Exception;

class IndexController extends \OPNsense\Base\IndexController
{
    const REPOSITORIES_TYPES = [
        'local',
        'sftp',
        'rest-server',
        'amazon-s3',
        'minio',
        's3-compatible',
        'wasabi',
        'alibaba-cloud',
        'openstack-swift',
        'backblaze-b2',
        'microsoft-azure-blob-storage',
        'google-cloud-storage',
        'other-services-via-rclone',
    ];

    public function indexAction()
    {
        $this->view->formGeneralSettings = $this->getForm("general");
        $repositories = [];
        foreach (self::REPOSITORIES_TYPES as $repository) {
            $name_uc = str_replace('-', ' ', ucwords($repository, '-'));
            $form_name = sprintf('Repository%sSettings', str_replace(' ', '', $name_uc));
            $form_id = sprintf('frm_%s', $form_name);
            try {
                $repositories[] = [
                    'name' => $repository,
                    'name_uc' => $name_uc,
                    'form_id' => $form_id,
                    'form_name' => $form_name,
                    'form_fields' => $this->getForm("respository_$repository"),
                ];
            } catch (Exception) {
                // ignore non yet existing templates
                continue;
            }
        }
        $this->view->repositories = $repositories;
        $this->view->pick('kumy/ResticBackup/index');
    }
}
