<?php

namespace kumy\ResticBackup;

class IndexController extends \OPNsense\Base\IndexController
{
    public function indexAction()
    {
        $this->view->formGeneralSettings = $this->getForm("general");
        $this->view->formRepositoryLocalSettings = $this->getForm("respository_local");
        $this->view->formRepositoryMinioSettings = $this->getForm("respository_minio");
        $this->view->pick('kumy/ResticBackup/index');
    }
}